import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/grupo_service.dart';
import '../services/tarea_grupo_service.dart';
import '../models/grupo.dart';
import '../models/tarea_grupo.dart';
import 'crear_tarea_grupo_screen.dart';

class GrupoScreen extends StatefulWidget {
  const GrupoScreen({super.key});

  @override
  State<GrupoScreen> createState() => _GrupoScreenState();
}

class _GrupoScreenState extends State<GrupoScreen> {
  bool _cargando = true;
  String? _errorCarga;
  String _rol = 'estudiante';
  Grupo? _grupo;

  final _nombreGrupoCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String? _error;
  bool _procesando = false;
  bool _modoCrear = true; // solo aplica cuando el rol es 'profesor'

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final rol = await AuthService.instance.obtenerRol();
      final grupo = await GrupoService.instance.obtenerMiGrupo();
      setState(() {
        _rol = rol;
        _grupo = grupo;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _errorCarga = 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.';
        _cargando = false;
      });
    }
  }

  Future<void> _crearGrupo() async {
    if (_nombreGrupoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un nombre para el grupo');
      return;
    }
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await GrupoService.instance.crearGrupo(_nombreGrupoCtrl.text.trim());
      await _cargar();
    } catch (e) {
      setState(() => _error = 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _unirseAGrupo() async {
    if (_codigoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el código del grupo');
      return;
    }
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final error = await GrupoService.instance.unirseAGrupo(_codigoCtrl.text);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      await _cargar();
    } catch (e) {
      setState(() => _error = 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorCarga != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grupo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_errorCarga!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _grupo != null ? _vistaGrupoActivo() : _vistaSinGrupo(),
      ),
      floatingActionButton: (_grupo != null && _rol == 'profesor')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrearTareaGrupoScreen(grupoId: _grupo!.codigo),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva tarea'),
            )
          : null,
    );
  }

  Widget _vistaSinGrupo() {
    return ListView(
      children: [
        if (_rol == 'profesor') ...[
          // El profesor puede crear un grupo nuevo O unirse a uno
          // existente con código (por si sale de un grupo por error
          // y necesita volver a entrar sin perder el que ya existía).
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Crear grupo')),
              ButtonSegment(value: false, label: Text('Unirme con código')),
            ],
            selected: {_modoCrear},
            onSelectionChanged: (seleccion) => setState(() {
              _modoCrear = seleccion.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_modoCrear) ...[
            const Text(
              'Crea un grupo para tu clase y comparte el código con tus estudiantes.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreGrupoCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del grupo (ej: 10-A Matemáticas)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _procesando ? null : _crearGrupo,
              child: _procesando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Crear grupo'),
            ),
          ] else ...[
            const Text(
              'Si ya tienes un código de un grupo (por ejemplo, uno que creaste antes y del que saliste sin querer), escríbelo aquí.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codigoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código del grupo'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _procesando ? null : _unirseAGrupo,
              child: _procesando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Unirme'),
            ),
          ],
        ] else ...[
          const Text(
            'Pídele el código a tu profesor y únete a su grupo.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Código del grupo'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _procesando ? null : _unirseAGrupo,
            child: _procesando
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Unirme'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _vistaGrupoActivo() {
    final grupo = _grupo!;
    return ListView(
      padding: EdgeInsets.only(bottom: _rol == 'profesor' ? 88 : 0),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grupo.nombre,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                if (_rol == 'profesor') ...[
                  Text(
                    'Código para tus estudiantes:',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    grupo.codigo,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Tareas del grupo', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<TareaGrupo>>(
          stream: TareaGrupoService.instance.obtenerTareas(grupo.codigo),
          builder: (context, snapshotTareas) {
            if (!snapshotTareas.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tareas = snapshotTareas.data!;
            if (tareas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no hay tareas publicadas.', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: tareas.map((t) => _TareaGrupoTile(tarea: t, grupo: grupo, esProfesor: _rol == 'profesor')).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Miembros del grupo', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: GrupoService.instance.obtenerMiembros(grupo.codigo),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final miembros = snapshot.data!;
            return Column(
              children: miembros
                  .map((m) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(m['nombre'] as String),
                      ))
                  .toList(),
            );
          },
        ),
        const Divider(height: 32),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmar = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Salir del grupo?'),
                content: Text(
                  _rol == 'profesor'
                      ? 'El grupo "${grupo.nombre}" sigue existiendo para los demás miembros, solo tú sales de él.'
                      : 'Vas a dejar de ver las tareas de "${grupo.nombre}". Puedes volver a unirte después con el mismo código.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            );
            if (confirmar == true) {
              await GrupoService.instance.salirDelGrupo(grupo.codigo);
              await _cargar();
            }
          },
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: const Text('Salir del grupo', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
      ],
    );
  }
}

/// Tarjeta expandible de una tarea del grupo: checkbox para marcar
/// completada uno mismo, y al expandir muestra quién del grupo ya la hizo.
class _TareaGrupoTile extends StatefulWidget {
  final TareaGrupo tarea;
  final Grupo grupo;
  final bool esProfesor;

  const _TareaGrupoTile({
    required this.tarea,
    required this.grupo,
    required this.esProfesor,
  });

  @override
  State<_TareaGrupoTile> createState() => _TareaGrupoTileState();
}

class _TareaGrupoTileState extends State<_TareaGrupoTile> {
  bool _expandido = false;

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text('"${widget.tarea.titulo}" se va a borrar para todo el grupo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await TareaGrupoService.instance.eliminarTarea(widget.grupo.codigo, widget.tarea.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dias = widget.tarea.diasRestantes;
    final textoFecha = dias < 0
        ? 'Venció'
        : dias == 0
            ? 'Vence hoy'
            : dias == 1
                ? 'Vence mañana'
                : 'Vence en $dias días';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: StreamBuilder<Set<String>>(
        stream: TareaGrupoService.instance.obtenerCompletadoPor(widget.grupo.codigo, widget.tarea.id),
        builder: (context, snapshot) {
          final completadoPor = snapshot.data ?? {};
          final yoCompleti = completadoPor.contains(uid);

          return Column(
            children: [
              ListTile(
                leading: Checkbox(
                  value: yoCompleti,
                  onChanged: (valor) => TareaGrupoService.instance
                      .marcarCompletada(widget.grupo.codigo, widget.tarea.id, valor ?? false),
                ),
                title: Text(widget.tarea.titulo),
                subtitle: Text(
                  '${widget.tarea.area} · $textoFecha · ${completadoPor.length} completaron'
                  '${widget.tarea.descripcion.isNotEmpty ? '\n${widget.tarea.descripcion}' : ''}',
                ),
                isThreeLine: widget.tarea.descripcion.isNotEmpty,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _expandido = !_expandido),
                    ),
                    if (widget.esProfesor) ...[
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CrearTareaGrupoScreen(
                              grupoId: widget.grupo.codigo,
                              tareaExistente: widget.tarea,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _eliminar,
                      ),
                    ],
                  ],
                ),
              ),
              if (_expandido)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: GrupoService.instance.obtenerMiembros(widget.grupo.codigo),
                  builder: (context, snapshotMiembros) {
                    if (!snapshotMiembros.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final miembros = snapshotMiembros.data!;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: miembros.map((m) {
                          final hecha = completadoPor.contains(m['uid']);
                          return Row(
                            children: [
                              Icon(
                                hecha ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 18,
                                color: hecha ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(m['nombre'] as String),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
