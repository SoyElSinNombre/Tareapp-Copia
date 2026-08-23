class Tarea {
  int? id;
  int materiaId;
  String titulo;
  String descripcion;
  DateTime fechaEntrega;
  bool completada;

  Tarea({
    this.id,
    required this.materiaId,
    required this.titulo,
    this.descripcion = '',
    required this.fechaEntrega,
    this.completada = false,
  });

  int get diasRestantes {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final entrega =
        DateTime(fechaEntrega.year, fechaEntrega.month, fechaEntrega.day);
    return entrega.difference(hoy).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'materiaId': materiaId,
      'titulo': titulo,
      'descripcion': descripcion,
      'fechaEntrega': fechaEntrega.toIso8601String(),
      'completada': completada ? 1 : 0,
    };
  }

  factory Tarea.fromMap(Map<String, dynamic> map) {
    return Tarea(
      id: map['id'] as int?,
      materiaId: map['materiaId'] as int,
      titulo: map['titulo'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      fechaEntrega: DateTime.parse(map['fechaEntrega'] as String),
      completada: (map['completada'] as int) == 1,
    );
  }
}
