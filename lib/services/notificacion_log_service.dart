import 'package:sqflite/sqflite.dart';
import 'db_service.dart';
import '../models/notificacion_log.dart';

/// Guarda un historial local de "avisos" (nueva tarea publicada,
/// tarea urgente) para que la persona los pueda revisar cuando
/// quiera en vez de depender solo de un aviso emergente al abrir la
/// app o de una notificación push que puede fallar en algunos
/// celulares.
class NotificacionLogService {
  NotificacionLogService._privateConstructor();
  static final NotificacionLogService instance = NotificacionLogService._privateConstructor();

  Future<Database> get _db => DBService.instance.database;

  /// Registra una entrada nueva. [claveUnica] evita duplicados: si ya
  /// existe una entrada con esa clave, no se vuelve a insertar (por
  /// ejemplo, para no repetir el mismo aviso cada vez que abres la
  /// app el mismo día).
  Future<void> registrar({
    required String tipo,
    required String titulo,
    required String cuerpo,
    required String claveUnica,
  }) async {
    final db = await _db;
    try {
      await db.insert(
        'notificaciones',
        {
          'tipo': tipo,
          'titulo': titulo,
          'cuerpo': cuerpo,
          'creadoEn': DateTime.now().toIso8601String(),
          'leida': 0,
          'claveUnica': claveUnica,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // ya existe -> se ignora, no es error
      );
    } catch (e) {
      // No queremos que un fallo al registrar en la bandeja tumbe
      // ningún otro flujo de la app (sincronización, notificaciones).
    }
  }

  Future<List<NotificacionLog>> obtenerPorTipo(String tipo) async {
    final db = await _db;
    final result = await db.query(
      'notificaciones',
      where: 'tipo = ?',
      whereArgs: [tipo],
      orderBy: 'creadoEn DESC',
    );
    return result.map((m) => NotificacionLog.fromMap(m)).toList();
  }

  Future<int> contarNoLeidas(String tipo) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM notificaciones WHERE tipo = ? AND leida = 0',
      [tipo],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> marcarTodasLeidas(String tipo) async {
    final db = await _db;
    await db.update(
      'notificaciones',
      {'leida': 1},
      where: 'tipo = ?',
      whereArgs: [tipo],
    );
  }

  Future<void> borrarTodo(String tipo) async {
    final db = await _db;
    await db.delete('notificaciones', where: 'tipo = ?', whereArgs: [tipo]);
  }
}
