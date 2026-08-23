import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Maneja el login/registro con Firebase Auth, y crea el documento del
/// usuario en Firestore con rol "estudiante" automáticamente.
///
/// Las cuentas de profesor NO se crean desde la app por seguridad — se
/// crean manualmente desde la consola de Firebase, cambiando el campo
/// 'rol' a 'profesor' directamente en Firestore.
class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Este es el "Web client ID" de la consola de Firebase (Authentication
  // → Sign-in method → Google → Configuración del SDK web). No es un
  // secreto — es un identificador público, seguro de dejar en el código.
  static const String _webClientId =
      '735930204883-u6ea4736m9vv5ctd2b0l8vj2q3iselep.apps.googleusercontent.com';

  bool _googleSignInInicializado = false;

  /// Debe llamarse una sola vez al arrancar la app, antes de usar
  /// cualquier método de Google Sign-In.
  Future<void> initGoogleSignIn() async {
    if (_googleSignInInicializado) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _googleSignInInicializado = true;
  }

  /// Emite el usuario actual cada vez que cambia el estado de sesión
  /// (login, logout, o al abrir la app con una sesión ya iniciada).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Registra una cuenta nueva con correo/contraseña y crea su perfil
  /// en Firestore. Retorna null si todo salió bien, o un mensaje de
  /// error en español listo para mostrar si algo falló.
  Future<String?> registrar({
    required String nombre,
    required String email,
    required String password,
  }) async {
    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _db.collection('usuarios').doc(credencial.user!.uid).set({
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': 'estudiante',
        'creadoEn': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.';
    }
  }

  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Sin conexión a internet. Revisa tu conexión e intenta de nuevo.';
    }
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  /// Inicia sesión con Google. Si es la primera vez que esta cuenta
  /// entra a la app, crea su perfil en Firestore con rol "estudiante"
  /// (igual que el registro por correo). Retorna null si todo salió
  /// bien, o un mensaje de error. Si el usuario simplemente cancela el
  /// selector de cuentas, retorna null sin hacer nada (no es un error).
  Future<String?> iniciarSesionConGoogle() async {
    try {
      await initGoogleSignIn();
      final googleUser = await GoogleSignIn.instance.authenticate();

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return 'No se pudo obtener la sesión de Google. Intenta de nuevo.';
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);

      final uid = userCredential.user!.uid;
      final perfil = await _db.collection('usuarios').doc(uid).get();
      if (!perfil.exists) {
        await _db.collection('usuarios').doc(uid).set({
          'nombre': googleUser.displayName ?? 'Sin nombre',
          'email': googleUser.email,
          'rol': 'estudiante',
          'creadoEn': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return 'No se pudo iniciar sesión con Google (${e.code}).';
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  /// Trae el rol del usuario actual desde Firestore ('estudiante' o
  /// 'profesor'). Si por alguna razón no existe el documento, asume
  /// 'estudiante' como valor seguro por defecto. Si no hay conexión,
  /// lanza una excepción clara en vez de quedarse esperando para siempre.
  Future<String> obtenerRol() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'estudiante';
    final doc = await _db
        .collection('usuarios')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    return (doc.data()?['rol'] as String?) ?? 'estudiante';
  }

  String _mensajeError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Intenta iniciar sesión.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu conexión.';
      default:
        return 'Ocurrió un error ($code). Intenta de nuevo.';
    }
  }
}
