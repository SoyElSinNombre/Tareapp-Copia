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
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
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
    // Respaldo por si las notificaciones en segundo plano fallan (pasa
    // en algunos celulares que restringen mucho las apps de terceros):
    // apenas se abre la app, avisamos si hay tareas urgentes.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _mostrarAvisoLegal();
      try {
        await PushService.instance.init();
      } catch (e) {
        debugPrint('No se pudo inicializar PushService: $e');
      }
      await _revisarTareasUrgentes();
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

  Future<void> _revisarTareasUrgentes() async {
    // --- Tareas locales (personales) ---
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
    ];

    // --- Tareas del grupo (si pertenezco a uno) ---
    // Aprovechamos este mismo momento (apertura de la app) para
    // sincronizar los recordatorios locales de cada tarea del grupo,
    // ya que no hay servidor que empuje notificaciones automáticamente.
    try {
      final grupo = await GrupoService.instance.obtenerMiGrupo();
      if (grupo != null) {
        final tareasGrupo = await TareaGrupoService.instance.obtenerTareasUnaVez(grupo.codigo);
        for (final tg in tareasGrupo) {
          final yaCompleti = await TareaGrupoService.instance.yoCompleteEsta(grupo.codigo, tg.id);
          if (yaCompleti) continue;

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

          if (tg.diasRestantes <= 3) {
            items.add(_ItemUrgente(
              titulo: tg.titulo,
              area: '${tg.area} · grupo',
              diasRestantes: tg.diasRestantes,
            ));
          }
        }
      }
    } catch (e) {
      // Sin internet o algún fallo con Firestore: no bloqueamos el
      // aviso de tareas locales por esto, simplemente lo omitimos.
      debugPrint('No se pudieron sincronizar tareas del grupo: $e');
    }

    items.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));

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
