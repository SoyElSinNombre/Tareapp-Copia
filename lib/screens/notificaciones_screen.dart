import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notificacion_log.dart';
import '../services/notificacion_log_service.dart';
import '../theme/app_theme.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _marcarLeidasPestanaActual();
      }
    });
    // Al abrir la bandeja, la pestaña visible (Nuevas) se marca leída.
    WidgetsBinding.instance.addPostFrameCallback((_) => _marcarLeidasPestanaActual());
  }

  Future<void> _marcarLeidasPestanaActual() async {
    final tipo = _tabController.index == 0 ? 'nueva_tarea' : 'urgente';
    await NotificacionLogService.instance.marcarTodasLeidas(tipo);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Nuevas tareas'),
            Tab(text: 'Urgentes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ListaNotificaciones(tipo: 'nueva_tarea'),
          _ListaNotificaciones(tipo: 'urgente'),
        ],
      ),
    );
  }
}

class _ListaNotificaciones extends StatefulWidget {
  final String tipo;
  const _ListaNotificaciones({required this.tipo});

  @override
  State<_ListaNotificaciones> createState() => _ListaNotificacionesState();
}

class _ListaNotificacionesState extends State<_ListaNotificaciones> {
  List<NotificacionLog> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await NotificacionLogService.instance.obtenerPorTipo(widget.tipo);
    if (mounted) {
      setState(() {
        _items = items;
        _cargando = false;
      });
    }
  }

  Future<void> _borrarTodo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar historial?'),
        content: const Text('Se van a borrar todas las notificaciones de esta pestaña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await NotificacionLogService.instance.borrarTodo(widget.tipo);
      _cargar();
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 1) return 'ahora mismo';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} día(s)';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.tipo == 'nueva_tarea' ? Icons.assignment_add : Icons.timer_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                widget.tipo == 'nueva_tarea'
                    ? 'Aquí verás un aviso cuando tu profesor publique una tarea nueva.'
                    : 'Aquí verás tus tareas próximas a vencer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _borrarTodo,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Borrar historial'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final item = _items[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.leida
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : AppColors.gold.withValues(alpha: 0.25),
                    child: Icon(
                      widget.tipo == 'nueva_tarea' ? Icons.assignment : Icons.timer,
                      color: item.leida ? Theme.of(context).colorScheme.outline : AppColors.gold,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.titulo,
                    style: GoogleFonts.lora(
                      fontWeight: item.leida ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text('${item.cuerpo}\n${_tiempoRelativo(item.creadoEn)}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
