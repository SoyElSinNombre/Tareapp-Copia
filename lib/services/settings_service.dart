import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'db_service.dart';

/// Guarda la configuración global de la app: cuántos periodos maneja el
/// colegio, qué % vale cada uno por defecto, la nota de aprobación y la
/// hora del recordatorio diario de tareas.
///
/// Se guarda como una sola fila en una tabla 'ajustes' (clave-valor simple).
class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  static const _defaultPesos = [30.0, 30.0, 40.0];
  static const _defaultNotaAprobacion = 3.0;
  static const _defaultHoraRecordatorio = 18; // 6:00 PM
  static const _defaultMinutoRecordatorio = 0;

  Future<Database> get _db => DBService.instance.database;

  Future<void> _asegurarTabla() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ajustes (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');
  }

  Future<String?> _leer(String clave) async {
    await _asegurarTabla();
    final db = await _db;
    final result =
        await db.query('ajustes', where: 'clave = ?', whereArgs: [clave]);
    if (result.isEmpty) return null;
    return result.first['valor'] as String?;
  }

  Future<void> _escribir(String clave, String valor) async {
    await _asegurarTabla();
    final db = await _db;
    await db.insert(
      'ajustes',
      {'clave': clave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<double>> obtenerPesosPorDefecto() async {
    final valor = await _leer('pesosPorDefecto');
    if (valor == null) return _defaultPesos;
    return (jsonDecode(valor) as List).map((e) => (e as num).toDouble()).toList();
  }

  Future<void> guardarPesosPorDefecto(List<double> pesos) async {
    await _escribir('pesosPorDefecto', jsonEncode(pesos));
  }

  Future<double> obtenerNotaAprobacion() async {
    final valor = await _leer('notaAprobacion');
    if (valor == null) return _defaultNotaAprobacion;
    return double.parse(valor);
  }

  Future<void> guardarNotaAprobacion(double nota) async {
    await _escribir('notaAprobacion', nota.toString());
  }

  Future<(int, int)> obtenerHoraRecordatorio() async {
    final valor = await _leer('horaRecordatorio');
    if (valor == null) return (_defaultHoraRecordatorio, _defaultMinutoRecordatorio);
    final partes = valor.split(':');
    return (int.parse(partes[0]), int.parse(partes[1]));
  }

  Future<void> guardarHoraRecordatorio(int hora, int minuto) async {
    await _escribir('horaRecordatorio', '$hora:$minuto');
  }

  Future<bool> obtenerModoOscuro() async {
    final valor = await _leer('modoOscuro');
    return valor == 'true';
  }

  Future<void> guardarModoOscuro(bool activado) async {
    await _escribir('modoOscuro', activado.toString());
  }
}
