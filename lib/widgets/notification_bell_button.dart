import 'package:flutter/material.dart';
import '../services/notificacion_log_service.dart';
import '../screens/notificaciones_screen.dart';
import '../theme/app_theme.dart';

/// Ícono de campanita con un contador de notificaciones sin leer,
/// que abre la bandeja de notificaciones al tocarlo. Se agrega en la
/// barra superior de cada pantalla principal.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargarConteo();
  }

  Future<void> _cargarConteo() async {
    final nuevas = await NotificacionLogService.instance.contarNoLeidas('nueva_tarea');
    final urgentes = await NotificacionLogService.instance.contarNoLeidas('urgente');
    if (mounted) setState(() => _noLeidas = nuevas + urgentes);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        label: Text('$_noLeidas'),
        isLabelVisible: _noLeidas > 0,
        backgroundColor: AppColors.maroon,
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: 'Notificaciones',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
        );
        _cargarConteo();
      },
    );
  }
}
