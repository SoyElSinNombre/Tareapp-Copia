import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    await _agregarMiembro(codigo);
    await _db
        .collection('usuarios')
        .doc(uid)
        .update({'grupoId': codigo}).timeout(const Duration(seconds: 10));

    return codigo;
  }

  /// Une al usuario actual a un grupo existente por su código.
  /// Retorna null si todo salió bien, o un mensaje de error.
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

    await _agregarMiembro(codigo);
    await _db
        .collection('usuarios')
        .doc(_auth.currentUser!.uid)
        .update({'grupoId': codigo}).timeout(const Duration(seconds: 10));

    return null;
  }

  Future<void> _agregarMiembro(String codigo) async {
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
      'unidoEn': FieldValue.serverTimestamp(),
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

  /// Stream en vivo de los miembros del grupo (nombre + uid), para
  /// mostrar la lista y cruzarla con quién completó cada tarea.
  Stream<List<Map<String, dynamic>>> obtenerMiembros(String codigo) {
    return _db
        .collection('grupos')
        .doc(codigo)
        .collection('miembros')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'uid': d.id, 'nombre': d.data()['nombre'] as String})
            .toList());
  }
}
