import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _esRegistro = false;
  bool _cargando = false;
  bool _cargandoGoogle = false;
  String? _error;

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final String? error;
    if (_esRegistro) {
      error = await AuthService.instance.registrar(
        nombre: _nombreCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    } else {
      error = await AuthService.instance.iniciarSesion(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = error;
    });
    // Si no hay error, el StreamBuilder en main.dart detecta el cambio
    // de sesión automáticamente y navega solo — no hace falta Navigator.
  }

  Future<void> _entrarConGoogle() async {
    setState(() {
      _cargandoGoogle = true;
      _error = null;
    });

    final error = await AuthService.instance.iniciarSesionConGoogle();

    if (!mounted) return;
    setState(() {
      _cargandoGoogle = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 72, color: Colors.indigo),
                  const SizedBox(height: 12),
                  Text(
                    'TareApp',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _esRegistro ? 'Crea tu cuenta de estudiante' : 'Inicia sesión',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 32),
                  if (_esRegistro) ...[
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Escribe tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Escribe tu correo';
                      if (!v.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Escribe tu contraseña';
                      if (_esRegistro && v.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_cargando || _cargandoGoogle) ? null : _enviar,
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_esRegistro ? 'Registrarme' : 'Entrar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_cargando || _cargandoGoogle)
                        ? null
                        : () => setState(() {
                              _esRegistro = !_esRegistro;
                              _error = null;
                            }),
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_cargando || _cargandoGoogle) ? null : _entrarConGoogle,
                      icon: _cargandoGoogle
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continuar con Google'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
