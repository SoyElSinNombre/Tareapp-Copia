import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Maneja las notificaciones PUSH reales (enviadas por un servidor),
/// a diferencia de notification_service.dart que solo programa avisos
/// LOCALES (el mismo celular se recuerda solo).
///
/// El "token" es un identificador único que Google le da a esta
/// instalación de la app en este celular — es lo que un servidor usa
/// para decirle a Google "mándale un push a ESTE celular en particular".
class PushService {
  PushService._privateConstructor();
  static final PushService instance = PushService._privateConstructor();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init() async {
    // Pide permiso de notificaciones (en Android 13+; en versiones
    // viejas se concede automáticamente).
    await _messaging.requestPermission();

    await _guardarToken();

    // Si Google le asigna un token nuevo a este celular (pasa a veces,
    // ej. tras reinstalar la app), lo actualizamos en Firestore.
    _messaging.onTokenRefresh.listen((_) => _guardarToken());

    // Cuando la app está ABIERTA en primer plano, Android NO muestra
    // la notificación automáticamente — hay que mostrarla nosotros
    // usando el mismo mecanismo de notificaciones locales que ya
    // teníamos, reutilizando ese "canal" en vez de crear uno nuevo.
    FirebaseMessaging.onMessage.listen((mensaje) {
      final notificacion = mensaje.notification;
      if (notificacion != null) {
        NotificationService.instance.mostrarNotificacionInstantanea(
          titulo: notificacion.title ?? 'TareApp',
          cuerpo: notificacion.body ?? '',
        );
      }
    });
  }

  Future<void> _guardarToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('usuarios').doc(uid).update({'fcmToken': token});
  }
}
