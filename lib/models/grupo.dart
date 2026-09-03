/// Representa una clase/salón compartido en Firebase.
/// El código es el ID del documento en Firestore (ej: "MAT101"),
/// así no hace falta una búsqueda extra para encontrar el grupo.
class Grupo {
  final String codigo;
  final String nombre;
  final String creadoPor;
  /// La foto del grupo, comprimida y guardada como texto base64
  /// directamente en el documento (no usamos Firebase Storage porque
  /// ahora exige una tarjeta de crédito incluso para uso mínimo).
  final String? fotoBase64;
  /// Alternativa simple a la foto: una sigla corta como "10A" que se
  /// muestra en el sello del grupo cuando no hay foto.
  final String? sigla;

  Grupo({
    required this.codigo,
    required this.nombre,
    required this.creadoPor,
    this.fotoBase64,
    this.sigla,
  });

  factory Grupo.fromMap(String codigo, Map<String, dynamic> map) {
    return Grupo(
      codigo: codigo,
      nombre: map['nombre'] as String,
      creadoPor: map['creadoPor'] as String,
      fotoBase64: map['fotoBase64'] as String?,
      sigla: map['sigla'] as String?,
    );
  }
}
