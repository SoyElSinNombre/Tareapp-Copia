import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/grupo.dart';

class GrupoService {
  GrupoService._privateConstructor();
  static final GrupoService instance = GrupoService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Genera un código de 6 caracteres (letras mayúsculas + números,
  /// sin caracteres confusos como O/0 o I/1).
  String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Crea un grupo nuevo (solo profesores deberían hacer esto — la
  /// pantalla ya se encarga de no ofrecer este botón a estudiantes).
  /// Retorna el código generado.
  Future<String> crearGrupo(String nombre) async {
    final uid = _auth.currentUser!.uid;
    String codigo;
    // Reintenta si por mala suerte el código generado ya existe
    // (extremadamente improbable, pero mejor prevenir).
    while (true) {
      codigo = _generarCodigo();
      final existe = await _db
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!existe.exists) break;
    }

    await _db.collection('grupos').doc(codigo).set({
      'nombre': nombre,
      'creadoPor': uid,
      'creadoEn': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));

    await _agregarMiembro(codigo, 'profesor');
    await _db
        .collection('usuarios')
        .doc(uid)
        .update({'grupoId': codigo}).timeout(const Duration(seconds: 10));

    return codigo;
  }

  /// Une al usuario actual a un grupo existente por su código. Si es
  /// una cuenta de profesor, se une como CO-PROFESOR (con los mismos
  /// permisos que quien creó el grupo); si es estudiante, se une
  /// normal. Retorna null si todo salió bien, o un mensaje de error.
  Future<String?> unirseAGrupo(String codigo) async {
    codigo = codigo.trim().toUpperCase();

    bool existe;
    try {
      final snapshot = await _db
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 10));
      existe = snapshot.exists;
    } catch (e) {
      return 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.';
    }

    if (!existe) {
      return 'No existe ningún grupo con ese código. Revísalo con tu profesor.';
    }

    final uid = _auth.currentUser!.uid;
    final perfilUsuario = await _db.collection('usuarios').doc(uid).get();
    final miRol = (perfilUsuario.data()?['rol'] as String?) ?? 'estudiante';

    await _agregarMiembro(codigo, miRol);
    await _db
        .collection('usuarios')
        .doc(uid)
        .update({'grupoId': codigo}).timeout(const Duration(seconds: 10));

    return null;
  }

  Future<void> _agregarMiembro(String codigo, String rol) async {
    final uid = _auth.currentUser!.uid;
    final perfilUsuario =
        await _db.collection('usuarios').doc(uid).get();
    await _db
        .collection('grupos')
        .doc(codigo)
        .collection('miembros')
        .doc(uid)
        .set({
      'nombre': perfilUsuario.data()?['nombre'] ?? 'Sin nombre',
      'rol': rol,
      'unidoEn': FieldValue.serverTimestamp(),
    });
  }

  /// El rol del usuario actual DENTRO de este grupo específico
  /// ('profesor' o 'estudiante') — no es lo mismo que el rol general
  /// de su cuenta, aunque normalmente coinciden. Se usa para decidir
  /// quién ve los controles de profesor (crear/editar/borrar tareas).
  ///
  /// Si el documento de miembro no tiene el campo 'rol' (grupos
  /// creados antes de soportar co-profesores), se asume 'profesor'
  /// solo para quien creó el grupo, y 'estudiante' para los demás —
  /// así los grupos viejos siguen funcionando sin necesitar migración.
  Future<String> obtenerMiRolEnGrupo(Grupo grupo) async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db
        .collection('grupos')
        .doc(grupo.codigo)
        .collection('miembros')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    final rol = doc.data()?['rol'] as String?;
    if (rol != null) return rol;
    return uid == grupo.creadoPor ? 'profesor' : 'estudiante';
  }

  /// Abre el selector de imágenes, la recorta a cuadrada, la comprime
  /// bastante (para que quepa cómoda dentro del límite de 1MB de un
  /// documento de Firestore), y la guarda como texto base64 en el
  /// grupo. No usamos Firebase Storage a propósito: desde hace poco
  /// exige activar el plan de pago incluso para uso mínimo.
  ///
  /// Retorna null si el usuario canceló la selección o si todo salió
  /// bien. Si algo falla, retorna un mensaje de error.
  Future<String?> cambiarFotoDeGrupo(String codigo) async {
    final picker = ImagePicker();
    final XFile? archivo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (archivo == null) return null; // el usuario canceló, no es error

    try {
      final bytesOriginales = await archivo.readAsBytes();
      final decodificada = img.decodeImage(bytesOriginales);
      if (decodificada == null) {
        return 'No se pudo procesar esa imagen. Prueba con otra.';
      }

      // Recorta al cuadrado central y reduce a un tamaño de miniatura
      // — no necesitamos más resolución que la de un avatar pequeño.
      final lado = min(decodificada.width, decodificada.height);
      final recortada = img.copyCrop(
        decodificada,
        x: (decodificada.width - lado) ~/ 2,
        y: (decodificada.height - lado) ~/ 2,
        width: lado,
        height: lado,
      );
      final miniatura = img.copyResize(recortada, width: 200, height: 200);
      final jpgComprimido = img.encodeJpg(miniatura, quality: 70);
      final base64Str = base64Encode(jpgComprimido);

      // Margen de seguridad bajo el límite de 1MB de un documento de
      // Firestore (dejando espacio para los demás campos del grupo).
      if (base64Str.length > 700000) {
        return 'La imagen sigue siendo muy grande incluso comprimida. Prueba con otra foto.';
      }

      await _db.collection('grupos').doc(codigo).update({'fotoBase64': base64Str});
      return null;
    } catch (e, st) {
      debugPrint('❌ Error procesando la foto del grupo: $e');
      debugPrint('$st');
      return 'No se pudo procesar la imagen. Intenta de nuevo.';
    }
  }

  /// Quita la foto del grupo, para que vuelva a mostrarse la sigla
  /// (o la inicial del nombre, si tampoco hay sigla).
  Future<void> quitarFotoDeGrupo(String codigo) async {
    await _db.collection('grupos').doc(codigo).update({
      'fotoBase64': FieldValue.delete(),
    });
  }

  /// Guarda una "sigla" corta (ej: "10A") que se muestra en el sello
  /// del grupo cuando no hay foto — una alternativa simple y sin
  /// depender de procesar imágenes, por si eso falla en algún celular.
  Future<void> establecerSigla(String codigo, String sigla) async {
    await _db.collection('grupos').doc(codigo).update({
      'sigla': sigla.trim().toUpperCase(),
    });
  }

  /// Retorna el grupo del usuario actual, o null si no pertenece a
  /// ninguno. Si no hay conexión y no hay nada en caché, lanza una
  /// excepción clara en vez de quedarse esperando para siempre.
  Future<Grupo?> obtenerMiGrupo() async {
    final uid = _auth.currentUser!.uid;
    final perfilUsuario = await _db
        .collection('usuarios')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    final grupoId = perfilUsuario.data()?['grupoId'] as String?;
    if (grupoId == null) return null;

    final doc = await _db
        .collection('grupos')
        .doc(grupoId)
        .get()
        .timeout(const Duration(seconds: 10));
    if (!doc.exists) return null;
    return Grupo.fromMap(doc.id, doc.data()!);
  }

  /// Saca al usuario actual del grupo: borra su entrada de miembros y
  /// limpia el grupoId de su perfil. Si con esto el grupo queda sin
  /// ningún miembro, borra también el grupo completo: sus tareas, y
  /// todo lo que cuelga de cada tarea (quién la completó, avisos ya
  /// enviados) — para no dejar nada huérfano en Firestore.
  Future<void> salirDelGrupo(String codigo) async {
    final uid = _auth.currentUser!.uid;
    final grupoRef = _db.collection('grupos').doc(codigo);
    final miembrosRef = grupoRef.collection('miembros');

    await miembrosRef.doc(uid).delete();
    await _db.collection('usuarios').doc(uid).update({
      'grupoId': FieldValue.delete(),
    });

    // Revisa si quedó alguien más. Si no, borra el grupo entero.
    final quedan = await miembrosRef.limit(1).get();
    if (quedan.docs.isNotEmpty) return;

    await _borrarTareasDelGrupo(grupoRef);
    await grupoRef.delete();
  }

  /// Borra cada tarea del grupo junto con sus subcolecciones
  /// (completadas y avisosEnviados) antes de borrar el grupo en sí.
  /// Firestore NO borra subcolecciones automáticamente al borrar un
  /// documento padre, así que hay que hacerlo a mano.
  Future<void> _borrarTareasDelGrupo(DocumentReference grupoRef) async {
    final tareasSnap = await grupoRef.collection('tareas').get();

    for (final tareaDoc in tareasSnap.docs) {
      final completadasSnap = await tareaDoc.reference.collection('completadas').get();
      for (final d in completadasSnap.docs) {
        await d.reference.delete();
      }

      final avisosSnap = await tareaDoc.reference.collection('avisosEnviados').get();
      for (final d in avisosSnap.docs) {
        await d.reference.delete();
      }

      await tareaDoc.reference.delete();
    }
  }

  /// Deja pedida una solicitud de "recordatorio manual" para este
  /// grupo. No le habla directo a GitHub (eso expondría credenciales
  /// desde la app) — en vez de eso, guarda la solicitud en Firestore,
  /// y el script que corre cada 5 minutos la recoge y manda el
  /// recordatorio a quien no haya completado cada tarea del grupo.
  Future<void> solicitarRecordatorioManual(String codigo) async {
    await _db
        .collection('grupos')
        .doc(codigo)
        .collection('solicitudesRecordatorio')
        .add({
      'solicitadoPor': _auth.currentUser!.uid,
      'creadoEn': FieldValue.serverTimestamp(),
      'procesado': false,
    });
  }

  /// Stream en vivo de los miembros del grupo (nombre + uid + su rol
  /// dentro del grupo), para mostrar la lista, distinguir profesores
  /// de estudiantes, y cruzarla con quién completó cada tarea.
  Stream<List<Map<String, dynamic>>> obtenerMiembros(String codigo) {
    return _db
        .collection('grupos')
        .doc(codigo)
        .collection('miembros')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {
                  'uid': d.id,
                  'nombre': d.data()['nombre'] as String,
                  'rol': (d.data()['rol'] as String?) ?? 'estudiante',
                })
            .toList());
  }
}
