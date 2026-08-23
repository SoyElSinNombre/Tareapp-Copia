import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/materia.dart';
import '../models/tarea.dart';
import '../services/db_service.dart';
import '../services/prioridad_service.dart';
import '../services/notification_service.dart';
import 'crear_tarea_screen.dart';

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  List<Tarea> _tareas = [];
  Map<int, Materia> _materiasPorId = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final tareas = await DBService.instance.obtenerTareas();
    final materias = await DBService.instance.obtenerMaterias();
    setState(() {
      _tareas = tareas.where((t) => !t.completada).toList();
      _materiasPorId = {for (var m in materias) m.id!: m};
    });
    _ordenarPorPrioridad();
  }

  void _ordenarPorPrioridad() {
    _tareas.sort((a, b) {
      final materiaA = _materiasPorId[a.materiaId];
      final materiaB = _materiasPorId[b.materiaId];
      if (materiaA == null || materiaB == null) return 0;
      final prioridadA = PrioridadService.calcular(a, materiaA);
      final prioridadB = PrioridadService.calcular(b, materiaB);
      return prioridadB.compareTo(prioridadA); // mayor prioridad primero
    });
    setState(() {});
  }

  Future<void> _marcarCompletada(Tarea tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Marcar como hecha?'),
        content: Text('"${tarea.titulo}" va a salir de tu lista de pendientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, ya la hice'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    tarea.completada = true;
    await DBService.instance.actualizarTarea(tarea);

    // Se envuelve en try/catch para que, si falla cancelar la
    // notificación (pasa en algunos celulares), la tarea de todas
    // formas se marque como hecha y desaparezca de la lista.
    try {
      await NotificationService.instance.cancelarRecordatorio(tarea.id!);
    } catch (e) {
      debugPrint('No se pudo cancelar el recordatorio: $e');
    }

    _cargar();
  }

  Color _colorPrioridad(double prioridad) {
    if (prioridad >= 7) return Colors.red;
    if (prioridad >= 4) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tareas pendientes')),
      body: _tareas.isEmpty
          ? const Center(child: Text('No tienes tareas pendientes 🎉'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _tareas.length,
              itemBuilder: (context, index) {
                final tarea = _tareas[index];
                final materia = _materiasPorId[tarea.materiaId];
                if (materia == null) return const SizedBox.shrink();
                final prioridad = PrioridadService.calcular(tarea, materia);

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorPrioridad(prioridad),
                      child: Text(prioridad.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(tarea.titulo),
                    subtitle: Text(
                      '${materia.nombre} · ${tarea.diasRestantes <= 0 ? "Vence hoy o ya venció" : "Faltan ${tarea.diasRestantes} día(s)"}'
                      '${tarea.descripcion.isNotEmpty ? '\n${tarea.descripcion}' : ''}',
                    ),
                    isThreeLine: tarea.descripcion.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => _marcarCompletada(tarea),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CrearTareaScreen(tareaExistente: tarea),
                        ),
                      );
                      _cargar();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearTareaScreen()),
          );
          _cargar();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
