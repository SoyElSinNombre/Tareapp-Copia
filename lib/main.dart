import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/db_service.dart';
import 'services/auth_service.dart';
import 'services/grupo_service.dart';
import 'services/tarea_grupo_service.dart';
import 'services/push_service.dart';
import 'services/notificacion_log_service.dart';
import 'theme/app_theme.dart';
import 'models/tarea.dart';
import 'screens/home_screen.dart';
import 'screens/tareas_screen.dart';
import 'screens/ajustes_screen.dart';
import 'screens/login_screen.dart';
import 'screens/grupo_screen.dart';

/// Notifica a toda la app cuando cambia el modo oscuro/claro.
/// Cualquier pantalla puede hacer themeModeNotifier.value = ThemeMode.dark
/// y la app entera se redibuja con el tema nuevo al instante.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

/// true cuando hay cambios en la pantalla de Ajustes que no se han
/// guardado todavía (tocando "Guardar ajustes"). Se usa para avisar
/// antes de dejar cambiar de pestaña sin querer.
final ValueNotifier<bool> ajustesSinGuardarNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.initGoogleSignIn();

  await NotificationService.instance.init();

  // Carga la preferencia de modo oscuro guardada.
  final modoOscuro = await SettingsService.instance.obtenerModoOscuro();
  themeModeNotifier.value = modoOscuro ? ThemeMode.dark : ThemeMode.light;

  // Programa (o vuelve a programar) el recordatorio diario. Se envuelve
  // en try/catch para que, si algo falla aquí (ej. permisos), la app
  // siga abriendo normalmente en vez de quedarse congelada.
  try {
    final (hora, minuto) = await SettingsService.instance.obtenerHoraRecordatorio();
    await NotificationService.instance.programarRecordatorioDiario(hora, minuto);
  } catch (e) {
    debugPrint('No se pudo programar el recordatorio diario: $e');
  }

  runApp(const TareApp());
}

class TareApp extends StatelessWidget {
  const TareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, modo, _) {
        return MaterialApp(
          title: 'TareApp',
          debugShowCheckedModeBanner: false,
          themeMode: modo,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: StreamBuilder<User?>(
            stream: AuthService.instance.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data == null) {
                return const LoginScreen();
              }
              return const MainNav();
            },
          ),
        );
      },
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    TareasScreen(),
    GrupoScreen(),
    AjustesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _mostrarAvisoLegal();
      // El aviso de tareas LOCALES sale de inmediato (solo necesita
      // la base de datos del celular, no depende de internet).
      await _revisarTareasUrgentesLocales();

      // Todo lo relacionado al GRUPO (que sí necesita Firestore) se
      // hace en segundo plano, sin bloquear nada — los resultados
      // quedan en la bandeja de notificaciones (🔔) para revisar
      // cuando quieras, en vez de otro aviso emergente que demoraría
      // la app cada vez que abres.
      unawaited(_sincronizarGrupoEnSegundoPlano());
    });
  }

  Future<void> _mostrarAvisoLegal() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aviso'),
        content: const Text(
          'TareApp es un proyecto estudiantil independiente. No está afiliada, '
          'respaldada ni desarrollada por ningún colegio, universidad u otra '
          'institución educativa oficial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _revisarTareasUrgentesLocales() async {
    final tareas = await DBService.instance.obtenerTareas();
    final materias = await DBService.instance.obtenerMaterias();
    final materiasPorId = {for (var m in materias) m.id!: m};

    final items = <_ItemUrgente>[
      for (final t in tareas)
        if (!t.completada && t.diasRestantes <= 3)
          _ItemUrgente(
            titulo: t.titulo,
            area: materiasPorId[t.materiaId]?.nombre ?? '',
            diasRestantes: t.diasRestantes,
          ),
    ]..sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));

    if (items.isEmpty || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Tareas urgentes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            final texto = item.diasRestantes < 0
                ? 'Venció'
                : item.diasRestantes == 0
                    ? 'Vence hoy'
                    : item.diasRestantes == 1
                        ? 'Vence mañana'
                        : 'Vence en ${item.diasRestantes} días';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• ${item.titulo} (${item.area}) — $texto'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Todo lo que depende de Firestore (notificaciones push, tareas del
  /// grupo) corre aquí, en segundo plano, SIN bloquear la interfaz.
  /// En vez de mostrar otro diálogo emergente (que sería lo que hacía
  /// lenta la apertura de la app), cada cosa relevante se registra en
  /// la bandeja de notificaciones para revisar con calma.
  Future<void> _sincronizarGrupoEnSegundoPlano() async {
    try {
      await PushService.instance.init();
    } catch (e) {
      debugPrint('No se pudo inicializar PushService: $e');
    }

    try {
      final grupo = await GrupoService.instance.obtenerMiGrupo();
      if (grupo == null) return;

      final tareasGrupo = await TareaGrupoService.instance.obtenerTareasUnaVez(grupo.codigo);

      // Se procesan en paralelo (no una por una) para que termine rápido.
      await Future.wait(tareasGrupo.map((tg) async {
        final yaCompleti = await TareaGrupoService.instance.yoCompleteEsta(grupo.codigo, tg.id);
        if (yaCompleti) return;

        final hoy = DateTime.now().toIso8601String().substring(0, 10);

        // ¿Es una tarea recién publicada? (hace menos de un día, y no
        // fue creada por mí mismo si soy profesor)
        if (tg.creadoPor != FirebaseAuth.instance.currentUser?.uid) {
          try {
            await NotificacionLogService.instance.registrar(
              tipo: 'nueva_tarea',
              titulo: '${tg.area}: ${tg.titulo}',
              cuerpo: 'Tarea publicada en el grupo',
              claveUnica: 'nueva:${tg.id}',
            );
          } catch (_) {}
        }

        if (tg.diasRestantes <= 3) {
          final texto = tg.diasRestantes < 0
              ? 'Venció'
              : tg.diasRestantes == 0
                  ? 'Vence hoy'
                  : tg.diasRestantes == 1
                      ? 'Vence mañana'
                      : 'Vence en ${tg.diasRestantes} días';
          try {
            await NotificacionLogService.instance.registrar(
              tipo: 'urgente',
              titulo: '${tg.area}: ${tg.titulo}',
              cuerpo: '$texto · grupo',
              claveUnica: 'urgente:grupo:${tg.id}:$hoy',
            );
          } catch (_) {}
        }

        try {
          await NotificationService.instance.programarRecordatorioGrupo(
            tareaIdFirestore: tg.id,
            titulo: tg.titulo,
            area: tg.area,
            fechaEntrega: tg.fechaEntrega,
            horasAntes: 24,
          );
          await NotificationService.instance.programarRecordatorioGrupo(
            tareaIdFirestore: tg.id,
            titulo: tg.titulo,
            area: tg.area,
            fechaEntrega: tg.fechaEntrega,
            horasAntes: 2,
          );
        } catch (e) {
          debugPrint('No se pudo programar recordatorio de tarea de grupo: $e');
        }
      }));
    } catch (e) {
      debugPrint('No se pudieron sincronizar tareas del grupo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (_index == 3 && i != 3 && ajustesSinGuardarNotifier.value) {
            final salir = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Salir sin guardar?'),
                content: const Text(
                    'Tienes cambios en Ajustes que no has guardado. Si sales ahora, se pierden.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Seguir editando'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Salir sin guardar'),
                  ),
                ],
              ),
            );
            if (salir != true) return;
            ajustesSinGuardarNotifier.value = false;
          }
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Materias'),
          NavigationDestination(
              icon: Icon(Icons.assignment), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Grupo'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

/// Representa una tarea urgente sin importar si viene de la base de
/// datos local (personal) o de Firestore (del grupo) — así el diálogo
/// de aviso puede mostrarlas juntas sin preocuparse de dónde salió cada una.
class _ItemUrgente {
  final String titulo;
  final String area;
  final int diasRestantes;

  _ItemUrgente({required this.titulo, required this.area, required this.diasRestantes});
}
