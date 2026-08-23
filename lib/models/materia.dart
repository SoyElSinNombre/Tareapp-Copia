import 'dart:convert';
import 'periodo.dart';

/// Representa un área/materia del colegio.
///
/// Cada [Periodo] guarda varias notas individuales (una por cada evaluación
/// o actividad calificada) y su promedio se calcula solo (suma / cantidad).
/// El peso de cada periodo (ej: 30%, 30%, 40%) se define al crear la
/// materia, tomando el valor por defecto configurado en Ajustes.
class Materia {
  int? id;
  String nombre;
  List<Periodo> periodos;
  double notaAprobacion;

  Materia({
    this.id,
    required this.nombre,
    required this.periodos,
    this.notaAprobacion = 3.0,
  });

  int get numPeriodos => periodos.length;

  /// Suma ponderada de los promedios de los periodos que YA tienen
  /// al menos una nota. Representa el avance actual sobre 5.0.
  double get avanceActual {
    double suma = 0;
    for (final p in periodos) {
      if (p.tieneNotas) {
        suma += p.promedio! * p.peso / 100;
      }
    }
    return suma;
  }

  /// Peso (en %) de los periodos que todavía no tienen ninguna nota.
  double get pesoFaltante {
    double faltante = 0;
    for (final p in periodos) {
      if (!p.tieneNotas) faltante += p.peso;
    }
    return faltante;
  }

  bool get completo => pesoFaltante == 0;

  double get promedioActual => avanceActual;

  /// [avanceActual] redondeado a una décima, como se acostumbra a
  /// reportar las notas en los colegios (ej: 3.15 -> 3.2).
  double get avanceRedondeado => _redondearDecima(avanceActual);

  /// Qué nota necesitas SACAR EN PROMEDIO en los periodos que aún no
  /// tienen ninguna nota, para llegar exactamente a [notaAprobacion].
  /// Retorna null si ya no faltan periodos por empezar.
  ///
  /// Nota: esto asume que los periodos que YA tienen notas están cerrados
  /// con su promedio actual. Si sigues agregando notas a un periodo en
  /// curso, este número se va a ir recalculando solo.
  double? notaNecesariaParaAprobar() {
    if (completo) return null;
    final necesaria = (notaAprobacion - avanceActual) * 100 / pesoFaltante;
    return necesaria;
  }

  /// [notaNecesariaParaAprobar] redondeada a una décima (ej: 3.15 -> 3.2).
  double? notaNecesariaRedondeada() {
    final necesaria = notaNecesariaParaAprobar();
    return necesaria == null ? null : _redondearDecima(necesaria);
  }

  /// Redondea al décimo más cercano (una sola cifra decimal), siguiendo
  /// la convención de "redondeo hacia arriba en el punto medio" que se
  /// usa normalmente en los colegios (3.15 -> 3.2, no 3.1).
  double _redondearDecima(double valor) => (valor * 10).round() / 10;

  bool esImposibleGanar({double notaMaxima = 5.0}) {
    final necesaria = notaNecesariaParaAprobar();
    if (necesaria == null) return avanceActual < notaAprobacion;
    return necesaria > notaMaxima;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'periodos': jsonEncode(periodos.map((p) => p.toJson()).toList()),
      'notaAprobacion': notaAprobacion,
    };
  }

  factory Materia.fromMap(Map<String, dynamic> map) {
    final periodosJson = jsonDecode(map['periodos'] as String) as List;
    return Materia(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      periodos: periodosJson
          .map((p) => Periodo.fromJson(p as Map<String, dynamic>))
          .toList(),
      notaAprobacion: (map['notaAprobacion'] as num).toDouble(),
    );
  }
}
