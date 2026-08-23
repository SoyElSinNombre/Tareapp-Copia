import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../services/db_service.dart';
import 'materia_detail_screen.dart';
import 'crear_materia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Materia> _materias = [];

  @override
  void initState() {
    super.initState();
    _cargarMaterias();
  }

  Future<void> _cargarMaterias() async {
    final materias = await DBService.instance.obtenerMaterias();
    setState(() => _materias = materias);
  }

  Color _colorPromedio(Materia m) {
    if (m.esImposibleGanar()) return Colors.red;
    if (m.promedioActual < m.notaAprobacion) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis materias')),
      body: _materias.isEmpty
          ? const Center(
              child: Text('Todavía no has agregado ninguna materia.\n'
                  'Toca el botón + para crear la primera.',
                  textAlign: TextAlign.center),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _materias.length,
              itemBuilder: (context, index) {
                final materia = _materias[index];
                final necesaria = materia.notaNecesariaRedondeada();
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(materia.nombre,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(necesaria == null
                        ? 'Materia completa'
                        : 'Necesitas ${necesaria.toStringAsFixed(1)} en lo que falta'),
                    trailing: CircleAvatar(
                      backgroundColor: _colorPromedio(materia),
                      child: Text(
                        materia.avanceRedondeado.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MateriaDetailScreen(materia: materia),
                        ),
                      );
                      _cargarMaterias();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearMateriaScreen()),
          );
          _cargarMaterias();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
