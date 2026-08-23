import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/materia.dart';
import '../models/tarea.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';

class CrearTareaScreen extends StatefulWidget {
  /// Si se pasa una tarea existente, la pantalla funciona en modo
  /// EDICIÓN en vez de creación (título, botones y comportamiento cambian).
  final Tarea? tareaExistente;

  const CrearTareaScreen({super.key, this.tareaExistente});

  bool get esEdicion => tareaExistente != null;

  @override
  State<CrearTareaScreen> createState() => _CrearTareaScreenState();
}

class _CrearTareaScreenState extends State<CrearTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  List<Materia> _materias = [];
  Materia? _materiaSeleccionada;
  DateTime? _fechaEntrega;

  @override
  void initState() {
    super.initState();
    final t = widget.tareaExistente;
    _tituloCtrl = TextEditingController(text: t?.titulo ?? '');
    _descripcionCtrl = TextEditingController(text: t?.descripcion ?? '');
    _fechaEntrega = t?.fechaEntrega;
    _cargarMaterias();
  }

  Future<void> _cargarMaterias() async {
    final materias = await DBService.instance.obtenerMaterias();
    setState(() {
      _materias = materias;
      if (widget.esEdicion) {
        final coincidencias = materias.where((m) => m.id == widget.tareaExistente!.materiaId);
        _materiaSeleccionada = coincidencias.isEmpty ? null : coincidencias.first;
      } else if (materias.isNotEmpty) {
        _materiaSeleccionada = materias.first;
      }
    });
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fechaEntrega = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_materiaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero crea al menos una materia')));
      return;
    }
    if (_fechaEntrega == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Elige una fecha de entrega')));
      return;
    }

    if (widget.esEdicion) {
      final tarea = widget.tareaExistente!;
      tarea.materiaId = _materiaSeleccionada!.id!;
      tarea.titulo = _tituloCtrl.text;
      tarea.descripcion = _descripcionCtrl.text;
      tarea.fechaEntrega = _fechaEntrega!;
      await DBService.instance.actualizarTarea(tarea);

      // Reprograma los recordatorios con la fecha/título nuevos (si
      // cambió la fecha, cancela el viejo y programa el correcto).
      try {
        await NotificationService.instance.cancelarRecordatorio(tarea.id!);
        if (!tarea.completada) {
          await NotificationService.instance
              .programarRecordatorio(tarea, _materiaSeleccionada!.nombre, horasAntes: 24);
          await NotificationService.instance
              .programarRecordatorio(tarea, _materiaSeleccionada!.nombre, horasAntes: 2);
        }
      } catch (e) {
        debugPrint('No se pudo reprogramar el recordatorio de la tarea: $e');
      }
    } else {
      final tarea = Tarea(
        materiaId: _materiaSeleccionada!.id!,
        titulo: _tituloCtrl.text,
        descripcion: _descripcionCtrl.text,
        fechaEntrega: _fechaEntrega!,
      );
      final id = await DBService.instance.crearTarea(tarea);
      tarea.id = id;

      try {
        await NotificationService.instance
            .programarRecordatorio(tarea, _materiaSeleccionada!.nombre, horasAntes: 24);
        await NotificationService.instance
            .programarRecordatorio(tarea, _materiaSeleccionada!.nombre, horasAntes: 2);
      } catch (e) {
        debugPrint('No se pudo programar el recordatorio de la tarea: $e');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.esEdicion ? 'Editar tarea' : 'Nueva tarea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título de la tarea'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Escribe un título' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Materia>(
                value: _materiaSeleccionada,
                decoration: const InputDecoration(labelText: 'Área'),
                items: _materias
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m.nombre)))
                    .toList(),
                onChanged: (m) => setState(() => _materiaSeleccionada = m),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_fechaEntrega == null
                    ? 'Elegir fecha de entrega'
                    : 'Entrega: ${_fechaEntrega!.day}/${_fechaEntrega!.month}/${_fechaEntrega!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _elegirFecha,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardar,
                child: Text(widget.esEdicion ? 'Guardar cambios' : 'Guardar tarea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
