import '../models/materia.dart';
import '../models/tarea.dart';

/// Calcula un puntaje de prioridad (0 a 10, más alto = más urgente)
/// combinando dos factores:
///  - urgencia: qué tan cerca está la fecha de entrega
///  - riesgo académico: qué tan mal vas en esa materia
///
/// Puedes ajustar los pesos (urgenciaPeso / riesgoPeso) si quieres que
/// pese más un factor que el otro.
class PrioridadService {
  static double calcular(
    Tarea tarea,
    Materia materia, {
    double urgenciaPeso = 0.6,
    double riesgoPeso = 0.4,
  }) {
    final dias = tarea.diasRestantes;

    // Urgencia: vencida o para hoy = máxima. Entre más días falten, baja.
    double urgencia;
    if (dias <= 0) {
      urgencia = 10;
    } else if (dias >= 10) {
      urgencia = 1;
    } else {
      urgencia = 10 - (dias * 0.9);
    }

    // Riesgo académico: si vas por debajo de la nota de aprobación,
    // o muy cerca de ella, sube la prioridad de esa materia.
    double riesgo;
    final promedio = materia.promedioActual;
    final diferencia = promedio - materia.notaAprobacion;
    if (diferencia < 0) {
      riesgo = 10; // vas perdiendo
    } else if (diferencia < 0.4) {
      riesgo = 6; // vas justo
    } else {
      riesgo = 2; // vas bien
    }

    return (urgencia * urgenciaPeso) + (riesgo * riesgoPeso);
  }
}
