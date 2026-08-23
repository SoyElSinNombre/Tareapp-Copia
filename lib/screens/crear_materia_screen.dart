import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../models/periodo.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';

class CrearMateriaScreen extends StatefulWidget {
  const CrearMateriaScreen({super.key});

  @override
  State<CrearMateriaScreen> createState() => _CrearMateriaScreenState();
}

class _CrearMateriaScreenState extends State<CrearMateriaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  List<double> _pesosPorDefecto = [];
  double _notaAprobacion = 3.0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarAjustes();
  }

  Future<void> _cargarAjustes() async {
    final pesos = await SettingsService.instance.obtenerPesosPorDefecto();
    final notaAprobacion = await SettingsService.instance.obtenerNotaAprobacion();
    setState(() {
      _pesosPorDefecto = pesos;
      _notaAprobacion = notaAprobacion;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final materia = Materia(
      nombre: _nombreCtrl.text,
      periodos: _pesosPorDefecto.map((peso) => Periodo(peso: peso)).toList(),
      notaAprobacion: _notaAprobacion,
    );
    await DBService.instance.crearMateria(materia);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva materia')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del área'),
                autofocus: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Se creará con estos periodos (configurables en Ajustes):',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pesosPorDefecto
                            .asMap()
                            .entries
                            .map((e) => 'Periodo ${e.key + 1}: ${e.value.toStringAsFixed(0)}%')
                            .join('  ·  '),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardar,
                child: const Text('Guardar materia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
