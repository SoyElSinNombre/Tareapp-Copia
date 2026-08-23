import 'package:flutter/material.dart';
import '../models/tarea_grupo.dart';
import '../services/tarea_grupo_service.dart';

class CrearTareaGrupoScreen extends StatefulWidget {
  final String grupoId;
  /// Si se pasa una tarea existente, la pantalla funciona en modo
  /// EDICIÓN en vez de creación.
  final TareaGrupo? tareaExistente;

  const CrearTareaGrupoScreen({super.key, required this.grupoId, this.tareaExistente});

  bool get esEdicion => tareaExistente != null;

  @override
  State<CrearTareaGrupoScreen> createState() => _CrearTareaGrupoScreenState();
}

class _CrearTareaGrupoScreenState extends State<CrearTareaGrupoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _areaCtrl;
  DateTime? _fechaEntrega;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tareaExistente;
    _tituloCtrl = TextEditingController(text: t?.titulo ?? '');
    _descripcionCtrl = TextEditingController(text: t?.descripcion ?? '');
    _areaCtrl = TextEditingController(text: t?.area ?? '');
    _fechaEntrega = t?.fechaEntrega;
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
    if (_fechaEntrega == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Elige una fecha de entrega')));
      return;
    }

    setState(() => _guardando = true);

    if (widget.esEdicion) {
      await TareaGrupoService.instance.editarTarea(
        grupoId: widget.grupoId,
        tareaId: widget.tareaExistente!.id,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        fechaEntrega: _fechaEntrega!,
      );
    } else {
      await TareaGrupoService.instance.crearTarea(
        grupoId: widget.grupoId,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        fechaEntrega: _fechaEntrega!,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.esEdicion ? 'Editar tarea del grupo' : 'Nueva tarea del grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título de la tarea'),
                autofocus: !widget.esEdicion,
                validator: (v) => (v == null || v.isEmpty) ? 'Escribe un título' : null,
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
              TextFormField(
                controller: _areaCtrl,
                decoration: const InputDecoration(labelText: 'Área (ej: Matemáticas)'),
                validator: (v) => (v == null || v.isEmpty) ? 'Escribe el área' : null,
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
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.esEdicion ? 'Guardar cambios' : 'Publicar tarea al grupo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
