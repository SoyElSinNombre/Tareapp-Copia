import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/grupo_service.dart';
import '../services/tarea_grupo_service.dart';
import '../models/grupo.dart';
import '../models/tarea_grupo.dart';
import '../theme/app_theme.dart';
import '../widgets/seal_avatar.dart';
import '../widgets/grupo_info_drawer.dart';
import '../widgets/notification_bell_button.dart';
import 'crear_tarea_grupo_screen.dart';

class GrupoScreen extends StatefulWidget {
  const GrupoScreen({super.key});

  @override
  State<GrupoScreen> createState() => _GrupoScreenState();
}

class _GrupoScreenState extends State<GrupoScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _cargando = true;
  String? _errorCarga;
  String _rol = 'estudiante';
  String _miRolEnGrupo = 'estudiante';
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
      final miRolEnGrupo = grupo != null
          ? await GrupoService.instance.obtenerMiRolEnGrupo(grupo)
          : 'estudiante';
      setState(() {
        _rol = rol;
        _grupo = grupo;
        _miRolEnGrupo = miRolEnGrupo;
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

  Future<void> _confirmarSalir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del grupo?'),
        content: Text(
          _miRolEnGrupo == 'profesor'
              ? 'El grupo "${_grupo!.nombre}" sigue existiendo para los demás miembros, solo tú sales de él.'
              : 'Vas a dejar de ver las tareas de "${_grupo!.nombre}". Puedes volver a unirte después con el mismo código.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      if (mounted) Navigator.pop(context); // cierra el drawer
      await GrupoService.instance.salirDelGrupo(_grupo!.codigo);
      await _cargar();
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

    final grupo = _grupo;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(grupo?.nombre ?? 'Grupo'),
        actions: [
          const NotificationBellButton(),
          if (grupo != null)
            IconButton(
              icon: SealAvatar(fotoBase64: grupo.fotoBase64, sigla: grupo.sigla, letra: grupo.nombre, radius: 16),
              tooltip: 'Información del grupo',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: grupo != null
          ? GrupoInfoDrawer(
              grupo: grupo,
              rol: _miRolEnGrupo,
              onGrupoActualizado: _cargar,
              onSalir: _confirmarSalir,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: grupo != null ? _vistaGrupoActivo(grupo) : _vistaSinGrupo(),
      ),
      floatingActionButton: (grupo != null && _miRolEnGrupo == 'profesor')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrearTareaGrupoScreen(grupoId: grupo.codigo),
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
            Text(
              'Crea un grupo para tu clase y comparte el código con tus estudiantes.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear grupo'),
            ),
          ] else ...[
            Text(
              'Si ya tienes un código de un grupo (por ejemplo, uno que creaste antes y del que saliste sin querer), escríbelo aquí.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Unirme'),
            ),
          ],
        ] else ...[
          Text(
            'Pídele el código a tu profesor y únete a su grupo.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Unirme'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.maroon)),
        ],
      ],
    );
  }

  Widget _vistaGrupoActivo(Grupo grupo) {
    return StreamBuilder<List<TareaGrupo>>(
      stream: TareaGrupoService.instance.obtenerTareas(grupo.codigo),
      builder: (context, snapshotTareas) {
        if (!snapshotTareas.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tareas = snapshotTareas.data!;
        if (tareas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    _miRolEnGrupo == 'profesor'
                        ? 'Todavía no has publicado ninguna tarea.\nToca "Nueva tarea" para empezar.'
                        : 'Todavía no hay tareas publicadas en este grupo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(bottom: _miRolEnGrupo == 'profesor' ? 88 : 0),
          itemCount: tareas.length,
          itemBuilder: (context, i) => _TareaGrupoTile(
            tarea: tareas[i],
            grupo: grupo,
            esProfesor: _miRolEnGrupo == 'profesor',
          ),
        );
      },
    );
  }
}

/// Tarjeta de una tarea del grupo, reorganizada en dos filas claras:
/// arriba el checkbox + título + datos clave; abajo, separadas por una
/// línea, las acciones (editar/eliminar/expandir). La descripción y la
/// lista de "quién completó" solo se muestran al tocar la flechita.
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
            style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
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
    final vencePronto = dias <= 1;
    final textoFecha = dias < 0
        ? 'Venció'
        : dias == 0
            ? 'Vence hoy'
            : dias == 1
                ? 'Vence mañana'
                : 'Vence en $dias días';

    return Card(
      child: StreamBuilder<Set<String>>(
        stream: TareaGrupoService.instance.obtenerCompletadoPor(widget.grupo.codigo, widget.tarea.id),
        builder: (context, snapshot) {
          final completadoPor = snapshot.data ?? {};
          final yoCompleti = completadoPor.contains(uid);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: yoCompleti,
                      onChanged: (valor) => TareaGrupoService.instance
                          .marcarCompletada(widget.grupo.codigo, widget.tarea.id, valor ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
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
                                _Etiqueta(texto: widget.tarea.area, icono: Icons.menu_book_outlined),
                                _Etiqueta(
                                  texto: textoFecha,
                                  icono: Icons.event_outlined,
                                  destacado: vencePronto,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.people_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${completadoPor.length} completaron',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                    const Spacer(),
                    if (widget.esProfesor) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar',
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
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.maroon),
                        tooltip: 'Eliminar',
                        onPressed: _eliminar,
                      ),
                    ],
                    IconButton(
                      icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
                      tooltip: _expandido ? 'Ver menos' : 'Ver detalles',
                      onPressed: () => setState(() => _expandido = !_expandido),
                    ),
                  ],
                ),
              ),
              if (_expandido)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.tarea.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.tarea.descripcion,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'QUIÉN LA HA COMPLETADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: GrupoService.instance.obtenerMiembros(widget.grupo.codigo),
                        builder: (context, snapshotMiembros) {
                          if (!snapshotMiembros.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(),
                            );
                          }
                          final miembros = snapshotMiembros.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: miembros.map((m) {
                              final hecha = completadoPor.contains(m['uid']);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      hecha ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: hecha ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(m['nombre'] as String, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pequeña etiqueta tipo "chip" para mostrar área/fecha de forma
/// compacta, sin que el texto se desborde y arrastre el diseño.
class _Etiqueta extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool destacado;

  const _Etiqueta({required this.texto, required this.icono, this.destacado = false});

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
