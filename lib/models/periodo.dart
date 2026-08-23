import 'nota_entry.dart';

/// Un periodo académico (ej: "Periodo 1") con su peso (%) y todas las
/// notas individuales que se han ido tomando en clase durante ese periodo.
class Periodo {
  double peso; // porcentaje que vale este periodo, ej: 30
  List<NotaEntry> notas;

  Periodo({required this.peso, List<NotaEntry>? notas}) : notas = notas ?? [];

  /// Promedio simple de todas las notas de este periodo:
  /// suma de notas / cantidad de notas. Null si no hay ninguna nota aún.
  double? get promedio {
    if (notas.isEmpty) return null;
    final suma = notas.fold<double>(0, (a, n) => a + n.valor);
    return suma / notas.length;
  }

  bool get tieneNotas => notas.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'peso': peso,
        'notas': notas.map((n) => n.toJson()).toList(),
      };

  factory Periodo.fromJson(Map<String, dynamic> json) => Periodo(
        peso: (json['peso'] as num).toDouble(),
        notas: (json['notas'] as List)
            .map((n) => NotaEntry.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}
