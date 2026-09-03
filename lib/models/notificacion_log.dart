/// Una entrada en la bandeja de notificaciones dentro de la app.
/// [tipo] es 'nueva_tarea' o 'urgente' — se usa para separarlas en
/// las dos pestañas de la bandeja.
class NotificacionLog {
  final int? id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final DateTime creadoEn;
  final bool leida;

  NotificacionLog({
    this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.creadoEn,
    this.leida = false,
  });

  factory NotificacionLog.fromMap(Map<String, dynamic> map) {
    return NotificacionLog(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      titulo: map['titulo'] as String,
      cuerpo: map['cuerpo'] as String,
      creadoEn: DateTime.parse(map['creadoEn'] as String),
      leida: (map['leida'] as int) == 1,
    );
  }
}
