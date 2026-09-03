import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../widgets/notification_bell_button.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  int _numPeriodos = 3;
  List<TextEditingController> _pesoCtrls = [];
  final _notaAprobacionCtrl = TextEditingController();
  TimeOfDay _horaRecordatorio = const TimeOfDay(hour: 18, minute: 0);
  bool _modoOscuro = false;
  String _rolUsuario = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _notaAprobacionCtrl.addListener(_marcarCambioSinGuardar);
    _cargar();
  }

  void _marcarCambioSinGuardar() {
    if (!_cargando) ajustesSinGuardarNotifier.value = true;
  }

  Future<void> _cargar() async {
    final pesos = await SettingsService.instance.obtenerPesosPorDefecto();
    final notaAprobacion = await SettingsService.instance.obtenerNotaAprobacion();
    final (hora, minuto) = await SettingsService.instance.obtenerHoraRecordatorio();
    final modoOscuro = await SettingsService.instance.obtenerModoOscuro();

    // El rol viene de Firestore (necesita internet) — el resto de esta
    // pantalla es 100% local, así que si no hay conexión no bloqueamos
    // todo, solo dejamos el rol en blanco (no se muestra el ícono/rol
    // en la tarjeta de cuenta hasta que haya señal).
    String rol = _rolUsuario;
    try {
      rol = await AuthService.instance.obtenerRol();
    } catch (e) {
      debugPrint('No se pudo verificar el rol (sin conexión probablemente): $e');
    }

    setState(() {
      _numPeriodos = pesos.length;
      _pesoCtrls = pesos.map((p) {
        final c = TextEditingController(text: p.toString());
        c.addListener(_marcarCambioSinGuardar);
        return c;
      }).toList();
      _notaAprobacionCtrl.text = notaAprobacion.toString();
      _horaRecordatorio = TimeOfDay(hour: hora, minute: minuto);
      _modoOscuro = modoOscuro;
      _rolUsuario = rol;
      _cargando = false;
    });
  }

  Future<void> _cambiarModoOscuro(bool activado) async {
    setState(() => _modoOscuro = activado);
    await SettingsService.instance.guardarModoOscuro(activado);
    themeModeNotifier.value = activado ? ThemeMode.dark : ThemeMode.light;
  }

  void _cambiarNumPeriodos(int n) {
    setState(() {
      _numPeriodos = n;
      final pesoIgual = (100 / n);
      _pesoCtrls = List.generate(n, (_) {
        final c = TextEditingController(text: pesoIgual.toStringAsFixed(0));
        c.addListener(_marcarCambioSinGuardar);
        return c;
      });
    });
    _marcarCambioSinGuardar();
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _horaRecordatorio,
    );
    if (hora != null) {
      setState(() => _horaRecordatorio = hora);
      _marcarCambioSinGuardar();
    }
  }

  Future<void> _guardar() async {
    final pesos = <double>[];
    for (final c in _pesoCtrls) {
      final valor = double.tryParse(c.text);
      if (valor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los porcentajes deben ser números válidos')),
        );
        return;
      }
      pesos.add(valor);
    }

    final suma = pesos.fold<double>(0, (a, b) => a + b);
    if ((suma - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Los porcentajes deben sumar 100 (ahora suman ${suma.toStringAsFixed(0)})')),
      );
      return;
    }

    final notaAprobacion = double.tryParse(_notaAprobacionCtrl.text);
    if (notaAprobacion == null || notaAprobacion < 0 || notaAprobacion > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La nota de aprobación debe ser un número entre 0 y 5')),
      );
      return;
    }

    await SettingsService.instance.guardarPesosPorDefecto(pesos);
    await SettingsService.instance.guardarNotaAprobacion(notaAprobacion);
    await SettingsService.instance
        .guardarHoraRecordatorio(_horaRecordatorio.hour, _horaRecordatorio.minute);

    // Envuelto en try/catch para que, si falla reprogramar la
    // notificación (pasa en algunos celulares), los ajustes de todas
    // formas queden guardados y la señal de "cambios sin guardar" se
    // apague correctamente.
    try {
      await NotificationService.instance
          .programarRecordatorioDiario(_horaRecordatorio.hour, _horaRecordatorio.minute);
    } catch (e) {
      debugPrint('No se pudo reprogramar el recordatorio diario: $e');
    }

    ajustesSinGuardarNotifier.value = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajustes guardados')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: const [NotificationBellButton(), SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _rolUsuario == 'profesor'
                      ? Colors.deepPurple
                      : Theme.of(context).colorScheme.primary,
                  child: Icon(
                    _rolUsuario == 'profesor' ? Icons.school : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(FirebaseAuth.instance.currentUser?.email ?? 'Sin correo'),
                subtitle: Text(
                  _rolUsuario == 'profesor' ? 'Cuenta de profesor' : 'Cuenta de estudiante',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Estos valores se usan cuando creas una materia nueva. '
              'Cambiarlos aquí no afecta las materias que ya creaste.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('¿Cuántos periodos maneja tu colegio?'),
            Wrap(
              spacing: 8,
              children: [3, 4].map((n) {
                return ChoiceChip(
                  label: Text('$n periodos'),
                  selected: _numPeriodos == n,
                  onSelected: (_) => _cambiarNumPeriodos(n),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Porcentaje de cada periodo (deben sumar 100):'),
            const SizedBox(height: 8),
            ...List.generate(_numPeriodos, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _pesoCtrls[i],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Periodo ${i + 1} (%)'),
                ),
              );
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _notaAprobacionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Nota mínima para aprobar'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora del recordatorio diario'),
              subtitle: Text(_horaRecordatorio.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _elegirHora,
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo oscuro'),
              subtitle: const Text('Cambia el tema de toda la app'),
              value: _modoOscuro,
              onChanged: _cambiarModoOscuro,
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await NotificationService.instance.mostrarNotificacionDePrueba();
                  debugPrint('✅ mostrarNotificacionDePrueba: sin errores');
                } catch (e, st) {
                  debugPrint('❌ ERROR en mostrarNotificacionDePrueba: $e');
                  debugPrint('$st');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificación de prueba enviada')),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Probar notificación ahora'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await NotificationService.instance.probarNotificacionProgramada();
                  debugPrint('✅ probarNotificacionProgramada: sin errores');
                } catch (e, st) {
                  debugPrint('❌ ERROR en probarNotificacionProgramada: $e');
                  debugPrint('$st');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Programada para dentro de 10 segundos, no cierres la app')),
                  );
                }
              },
              icon: const Icon(Icons.timer),
              label: const Text('Probar notificación en 10 segundos'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: const Text('Guardar ajustes'),
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Cerrar sesión?'),
                    content: const Text('Vas a tener que volver a iniciar sesión para usar la app.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  await AuthService.instance.cerrarSesion();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
