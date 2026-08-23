import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:permission_handler/permission_handler.dart';
import '../models/tarea.dart';

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService instance =
      NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // Sin esto, el paquete de notificaciones asume UTC por defecto, lo
    // cual hace que las horas programadas no coincidan con la hora real
    // del celular. Colombia no usa horario de verano, así que este
    // valor es fijo y no hay que recalcularlo en ninguna época del año.
    tz.setLocalLocation(tz.getLocation('America/Bogota'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // En Android 13+ hay que pedir permiso explícito para notificaciones.
    final estadoNotif = await Permission.notification.request();
    debugPrint('🔔 Permiso de notificaciones: $estadoNotif');

    // En Android 12+ hay un permiso especial separado para "alarmas
    // exactas" (Alarmas y recordatorios). Sin este permiso, algunos
    // fabricantes (como los XOS de Infinix) ni siquiera cumplen bien
    // las alarmas "inexactas", así que lo pedimos explícitamente.
    final estadoAlarma = await Permission.scheduleExactAlarm.request();
    debugPrint('⏰ Permiso de alarmas exactas: $estadoAlarma');

    // Sin exención de optimización de batería, Doze puede retrasar las
    // alarmas horas enteras, y los "asesinos de apps" de fabricantes
    // (XOS, MIUI, etc.) cancelan directamente las alarmas programadas.
    // Con este permiso el sistema trata a la app como excepción.
    final estadoBateria = await Permission.ignoreBatteryOptimizations.request();
    debugPrint('🔋 Exención de optimización de batería: $estadoBateria');
  }

  /// Programa una notificación [horasAntes] antes de la fecha de entrega
  /// de la tarea. Si esa fecha ya pasó, no programa nada.
  Future<void> programarRecordatorio(
    Tarea tarea,
    String nombreMateria, {
    int horasAntes = 24,
  }) async {
    if (tarea.id == null) return;

    final fechaNotificacion =
        tarea.fechaEntrega.subtract(Duration(hours: horasAntes));

    if (fechaNotificacion.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'recordatorios_tareas',
      'Recordatorios de tareas',
      channelDescription: 'Avisos de actividades próximas a vencer',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final ahora = DateTime.now();
    final diasFaltantes = tarea.fechaEntrega.difference(ahora).inDays;

    await _plugin.zonedSchedule(
      tarea.id!, // usamos el id de la tarea como id de notificación
      '$nombreMateria: ${tarea.titulo}',
      diasFaltantes <= 0
          ? '¡Se entrega hoy!'
          : 'Faltan $diasFaltantes día(s) para la entrega',
      tz.TZDateTime.from(fechaNotificacion, tz.local),
      details,
      androidScheduleMode: await _modoAlarma(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Prueba de diagnóstico: programa (no muestra al instante) una
  /// notificación para 10 segundos después, usando el mismo mecanismo
  /// que usan los recordatorios reales. Sirve para separar "el código
  /// de programar notificaciones tiene un bug" de "el sistema está
  /// matando la app en segundo plano antes de que llegue la hora".
  Future<void> probarNotificacionProgramada() async {
    const androidDetails = AndroidNotificationDetails(
      'prueba_programada',
      'Prueba programada',
      channelDescription: 'Canal de prueba para diagnosticar zonedSchedule',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final fechaHora = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _plugin.zonedSchedule(
      777777,
      'Prueba programada de TareApp',
      'Si ves esto 10 segundos después de tocar el botón, zonedSchedule funciona bien',
      fechaHora,
      details,
      androidScheduleMode: await _modoAlarma(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Usa alarma EXACTA si el usuario concedió el permiso especial de
  /// "Alarmas y recordatorios" (más confiable), y si no, cae de vuelta
  /// a inexacta (para no crashear como pasaba antes de pedir el permiso).
  Future<AndroidScheduleMode> _modoAlarma() async {
    final concedido = await Permission.scheduleExactAlarm.isGranted;
    return concedido
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Convierte el id de texto de una tarea de grupo (viene de Firestore)
  /// en un id numérico estable, ya que el plugin de notificaciones
  /// necesita un entero. Se usa un rango alto (sumando 500000000) para
  /// que nunca choque con los ids de tareas locales (que son pequeños,
  /// autoincrementales de SQLite).
  int _idNotificacionGrupo(String tareaIdFirestore) {
    return 500000000 + (tareaIdFirestore.hashCode & 0x3FFFFFFF);
  }

  /// Programa el recordatorio de una tarea del GRUPO (compartida), igual
  /// que [programarRecordatorio] pero a partir de los datos que vienen
  /// de Firestore en vez de un objeto [Tarea] local.
  Future<void> programarRecordatorioGrupo({
    required String tareaIdFirestore,
    required String titulo,
    required String area,
    required DateTime fechaEntrega,
    int horasAntes = 24,
  }) async {
    final id = _idNotificacionGrupo(tareaIdFirestore) + horasAntes; // 24h y 2h no chocan entre sí
    final fechaNotificacion = fechaEntrega.subtract(Duration(hours: horasAntes));
    if (fechaNotificacion.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'recordatorios_tareas_grupo',
      'Recordatorios de tareas del grupo',
      channelDescription: 'Avisos de tareas publicadas por tu profesor',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final diasFaltantes = fechaEntrega.difference(DateTime.now()).inDays;

    await _plugin.zonedSchedule(
      id,
      '$area (grupo): $titulo',
      diasFaltantes <= 0 ? '¡Se entrega hoy!' : 'Faltan $diasFaltantes día(s) para la entrega',
      tz.TZDateTime.from(fechaNotificacion, tz.local),
      details,
      androidScheduleMode: await _modoAlarma(),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelarRecordatorioGrupo(String tareaIdFirestore) async {
    final base = _idNotificacionGrupo(tareaIdFirestore);
    await _plugin.cancel(base + 24);
    await _plugin.cancel(base + 2);
  }

  /// Muestra una notificación al instante con título y cuerpo
  /// personalizados. La usa PushService para mostrar los avisos del
  /// servidor cuando la app está abierta (Android no los muestra solo
  /// en ese caso).
  Future<void> mostrarNotificacionInstantanea({
    required String titulo,
    required String cuerpo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'avisos_push',
      'Avisos del servidor',
      channelDescription: 'Notificaciones enviadas desde el servidor de tareas del grupo',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      titulo,
      cuerpo,
      details,
    );
  }

  Future<void> cancelarRecordatorio(int tareaId) async {
    await _plugin.cancel(tareaId);
  }

  /// Dispara una notificación AL INSTANTE, sin depender de alarmas
  /// programadas ni de zona horaria. Sirve para probar si el problema
  /// está en los permisos/canal (esto no funciona) o en la parte de
  /// programar para después (esto sí funciona, pero lo programado no llega).
  Future<void> mostrarNotificacionDePrueba() async {
    const androidDetails = AndroidNotificationDetails(
      'prueba_inmediata',
      'Prueba inmediata',
      channelDescription: 'Canal de prueba para diagnosticar notificaciones',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      888888,
      'Prueba de TareApp',
      'Si ves esto, las notificaciones básicas sí funcionan',
      details,
    );
  }

  // Usamos un id fijo y muy alto para que nunca choque con los ids de
  // tareas (que vienen de autoincrement de SQLite, normalmente bajos).
  static const int _idRecordatorioDiario = 999999;

  /// Programa (o reprograma) un recordatorio que se repite TODOS LOS DÍAS
  /// a la hora indicada, recordando revisar las tareas pendientes.
  Future<void> programarRecordatorioDiario(int hora, int minuto) async {
    const androidDetails = AndroidNotificationDetails(
      'recordatorio_diario',
      'Recordatorio diario',
      channelDescription: 'Aviso diario para revisar tareas pendientes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final ahora = tz.TZDateTime.now(tz.local);
    var fechaHora = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      hora,
      minuto,
    );
    // Si la hora de hoy ya pasó, programa para mañana.
    if (fechaHora.isBefore(ahora)) {
      fechaHora = fechaHora.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _idRecordatorioDiario,
      'TareApp',
      'Revisa tus tareas pendientes de hoy 📚',
      fechaHora,
      details,
      androidScheduleMode: await _modoAlarma(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // se repite cada día
    );
  }

  Future<void> cancelarRecordatorioDiario() async {
    await _plugin.cancel(_idRecordatorioDiario);
  }
}
