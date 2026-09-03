import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/materia.dart';
import '../models/tarea.dart';
import '../services/db_service.dart';
import '../services/prioridad_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_bell_button.dart';
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

    try {
      await NotificationService.instance.cancelarRecordatorio(tarea.id!);
    } catch (e) {
      debugPrint('No se pudo cancelar el recordatorio: $e');
    }

    _cargar();
  }

  Color _colorPrioridad(double prioridad) {
    if (prioridad >= 7) return AppColors.maroon;
    if (prioridad >= 4) return AppColors.gold;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas pendientes'),
        actions: const [NotificationBellButton(), SizedBox(width: 8)],
      ),
      body: _tareas.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt, size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes tareas pendientes',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _tareas.length,
              itemBuilder: (context, index) {
                final tarea = _tareas[index];
                final materia = _materiasPorId[tarea.materiaId];
                if (materia == null) return const SizedBox.shrink();
                final prioridad = PrioridadService.calcular(tarea, materia);

                return _TareaLocalTile(
                  tarea: tarea,
                  materiaNombre: materia.nombre,
                  prioridad: prioridad,
                  colorPrioridad: _colorPrioridad(prioridad),
                  onCompletar: () => _marcarCompletada(tarea),
                  onEditar: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CrearTareaScreen(tareaExistente: tarea)),
                    );
                    _cargar();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearTareaScreen()),
          );
          _cargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

/// Tarjeta de una tarea personal, con la misma estructura de dos filas
/// que las del grupo: arriba el contenido principal, abajo las
/// acciones. La descripción solo se ve al expandir.
class _TareaLocalTile extends StatefulWidget {
  final Tarea tarea;
  final String materiaNombre;
  final double prioridad;
  final Color colorPrioridad;
  final VoidCallback onCompletar;
  final VoidCallback onEditar;

  const _TareaLocalTile({
    required this.tarea,
    required this.materiaNombre,
    required this.prioridad,
    required this.colorPrioridad,
    required this.onCompletar,
    required this.onEditar,
  });

  @override
  State<_TareaLocalTile> createState() => _TareaLocalTileState();
}

class _TareaLocalTileState extends State<_TareaLocalTile> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final dias = widget.tarea.diasRestantes;
    final vencePronto = dias <= 1;
    final textoFecha = dias <= 0 ? 'Vence hoy o ya venció' : 'Faltan $dias día(s)';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.colorPrioridad,
                  child: Text(
                    widget.prioridad.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tarea.titulo,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _EtiquetaTarea(texto: widget.materiaNombre, icono: Icons.menu_book_outlined),
                          _EtiquetaTarea(texto: textoFecha, icono: Icons.event_outlined, destacado: vencePronto),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                if (widget.tarea.descripcion.isNotEmpty)
                  IconButton(
                    icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
                    tooltip: _expandido ? 'Ver menos' : 'Ver descripción',
                    onPressed: () => setState(() => _expandido = !_expandido),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar',
                  onPressed: widget.onEditar,
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Marcar como hecha',
                  onPressed: widget.onCompletar,
                ),
              ],
            ),
          ),
          if (_expandido && widget.tarea.descripcion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.tarea.descripcion,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _EtiquetaTarea extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool destacado;

  const _EtiquetaTarea({required this.texto, required this.icono, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    final color = destacado ? AppColors.maroon : Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          texto,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color,
            fontWeight: destacado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
