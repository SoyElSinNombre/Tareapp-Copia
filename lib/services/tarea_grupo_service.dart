import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tarea_grupo.dart';
import 'notification_service.dart';

class TareaGrupoService {
  TareaGrupoService._privateConstructor();
  static final TareaGrupoService instance = TareaGrupoService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _tareasRef(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('tareas');

  /// Solo el profesor debería llamar esto (la pantalla no muestra el
  /// botón a estudiantes, y las reglas de Firestore también lo bloquean).
  Future<void> crearTarea({
    required String grupoId,
    required String titulo,
    required String descripcion,
    required String area,
    required DateTime fechaEntrega,
  }) async {
    await _tareasRef(grupoId).add({
      'titulo': titulo,
      'descripcion': descripcion,
      'area': area,
      'fechaEntrega': Timestamp.fromDate(fechaEntrega),
      'creadoPor': _auth.currentUser!.uid,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Edita una tarea ya publicada. Solo el profesor que creó el grupo
  /// puede hacerlo — la pantalla no le muestra el botón a estudiantes,
  /// y las reglas de Firestore también lo bloquean del lado del servidor.
  Future<void> editarTarea({
    required String grupoId,
    required String tareaId,
    required String titulo,
    required String descripcion,
    required String area,
    required DateTime fechaEntrega,
  }) async {
    await _tareasRef(grupoId).doc(tareaId).update({
      'titulo': titulo,
      'descripcion': descripcion,
      'area': area,
      'fechaEntrega': Timestamp.fromDate(fechaEntrega),
    });
  }

  Future<void> eliminarTarea(String grupoId, String tareaId) async {
    await _tareasRef(grupoId).doc(tareaId).delete();
  }

  /// Lista en vivo de las tareas del grupo, ordenadas por fecha de entrega.
  Stream<List<TareaGrupo>> obtenerTareas(String grupoId) {
    return _tareasRef(grupoId)
        .orderBy('fechaEntrega')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TareaGrupo.fromDoc(d.id, d.data()))
            .toList());
  }

  /// Marca/desmarca la tarea como completada SOLO para el usuario actual.
  Future<void> marcarCompletada(String grupoId, String tareaId, bool completada) async {
    final uid = _auth.currentUser!.uid;
    final ref = _tareasRef(grupoId)
        .doc(tareaId)
        .collection('completadas')
        .doc(uid);
    if (completada) {
      await ref.set({'completadoEn': FieldValue.serverTimestamp()});
      try {
        await NotificationService.instance.cancelarRecordatorioGrupo(tareaId);
      } catch (_) {
        // Si falla cancelar el recordatorio, no es grave: en el peor
        // caso suena un recordatorio de algo que ya se hizo.
      }
    } else {
      await ref.delete();
    }
  }

  /// Stream con el conjunto de uids que han completado esta tarea.
  /// Sirve tanto para saber "¿yo ya la hice?" como para mostrar la
  /// lista de quién sí y quién no en todo el grupo.
  Stream<Set<String>> obtenerCompletadoPor(String grupoId, String tareaId) {
    return _tareasRef(grupoId)
        .doc(tareaId)
        .collection('completadas')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Consulta puntual (no en vivo) de si el usuario actual ya completó
  /// esta tarea. Útil para sincronizar recordatorios sin mantener un
  /// stream abierto todo el tiempo.
  Future<bool> yoCompleteEsta(String grupoId, String tareaId) async {
    final uid = _auth.currentUser!.uid;
    final doc = await _tareasRef(grupoId)
        .doc(tareaId)
        .collection('completadas')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    return doc.exists;
  }

  /// Lista puntual (no en vivo) de las tareas del grupo, para
  /// sincronizar recordatorios al abrir la app sin dejar un stream
  /// abierto de fondo.
  Future<List<TareaGrupo>> obtenerTareasUnaVez(String grupoId) async {
    final snap = await _tareasRef(grupoId)
        .orderBy('fechaEntrega')
        .get()
        .timeout(const Duration(seconds: 10));
    return snap.docs.map((d) => TareaGrupo.fromDoc(d.id, d.data())).toList();
  }
}
