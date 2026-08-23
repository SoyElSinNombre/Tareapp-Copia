/// Representa una clase/salón compartido en Firebase.
/// El código es el ID del documento en Firestore (ej: "MAT101"),
/// así no hace falta una búsqueda extra para encontrar el grupo.
class Grupo {
  final String codigo;
  final String nombre;
  final String creadoPor;

  Grupo({required this.codigo, required this.nombre, required this.creadoPor});

  factory Grupo.fromMap(String codigo, Map<String, dynamic> map) {
    return Grupo(
      codigo: codigo,
      nombre: map['nombre'] as String,
      creadoPor: map['creadoPor'] as String,
    );
  }
}
