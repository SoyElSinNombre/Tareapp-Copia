import 'package:cloud_firestore/cloud_firestore.dart';

/// Una tarea creada por el profesor, visible para todo el grupo.
/// A diferencia de [Tarea] (local, por estudiante), esta vive en
/// Firestore dentro de grupos/{grupoId}/tareas/{id}.
class TareaGrupo {
  final String id;
  final String titulo;
  final String descripcion;
  final String area;
  final DateTime fechaEntrega;
  final String creadoPor;

  TareaGrupo({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.area,
    required this.fechaEntrega,
    required this.creadoPor,
  });

  int get diasRestantes {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final entrega =
        DateTime(fechaEntrega.year, fechaEntrega.month, fechaEntrega.day);
    return entrega.difference(hoy).inDays;
  }

  factory TareaGrupo.fromDoc(String id, Map<String, dynamic> map) {
    return TareaGrupo(
      id: id,
      titulo: map['titulo'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      area: map['area'] as String,
      fechaEntrega: (map['fechaEntrega'] as Timestamp).toDate(),
      creadoPor: map['creadoPor'] as String,
    );
  }
}
