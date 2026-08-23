/// Una nota individual tomada en una fecha específica dentro de un periodo.
/// Ejemplo: 12/08/2026 -> 4.5
class NotaEntry {
  DateTime fecha;
  double valor;

  NotaEntry({required this.fecha, required this.valor});

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'valor': valor,
      };

  factory NotaEntry.fromJson(Map<String, dynamic> json) => NotaEntry(
        fecha: DateTime.parse(json['fecha'] as String),
        valor: (json['valor'] as num).toDouble(),
      );
}
