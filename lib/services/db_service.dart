import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/materia.dart';
import '../models/tarea.dart';

class DBService {
  DBService._privateConstructor();
  static final DBService instance = DBService._privateConstructor();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tareapp.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE materias (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            periodos TEXT NOT NULL,
            notaAprobacion REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tareas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            materiaId INTEGER NOT NULL,
            titulo TEXT NOT NULL,
            descripcion TEXT NOT NULL DEFAULT '',
            fechaEntrega TEXT NOT NULL,
            completada INTEGER NOT NULL,
            FOREIGN KEY (materiaId) REFERENCES materias (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE notificaciones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            titulo TEXT NOT NULL,
            cuerpo TEXT NOT NULL,
            creadoEn TEXT NOT NULL,
            leida INTEGER NOT NULL DEFAULT 0,
            claveUnica TEXT NOT NULL UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Cambiamos la estructura de notas (de una nota por periodo a
          // varias notas con fecha por periodo). No hay forma automática
          // de migrar los datos viejos a la estructura nueva, así que
          // reiniciamos la tabla de materias. Las tareas no se tocan.
          await db.execute('DROP TABLE IF EXISTS materias');
          await db.execute('''
            CREATE TABLE materias (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              periodos TEXT NOT NULL,
              notaAprobacion REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          // Agregamos descripción a las tareas. Esto sí se puede hacer
          // sin borrar nada — solo se agrega la columna nueva, vacía
          // para las tareas que ya existían.
          await db.execute("ALTER TABLE tareas ADD COLUMN descripcion TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 4) {
          // Tabla nueva para la bandeja de notificaciones — no afecta
          // nada de lo que ya existía.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS notificaciones (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              tipo TEXT NOT NULL,
              titulo TEXT NOT NULL,
              cuerpo TEXT NOT NULL,
              creadoEn TEXT NOT NULL,
              leida INTEGER NOT NULL DEFAULT 0,
              claveUnica TEXT NOT NULL UNIQUE
            )
          ''');
        }
      },
    );
  }

  // ---------- MATERIAS ----------

  Future<int> crearMateria(Materia materia) async {
    final db = await database;
    return await db.insert('materias', materia.toMap()..remove('id'));
  }

  Future<List<Materia>> obtenerMaterias() async {
    final db = await database;
    final result = await db.query('materias');
    return result.map((m) => Materia.fromMap(m)).toList();
  }

  Future<void> actualizarMateria(Materia materia) async {
    final db = await database;
    await db.update('materias', materia.toMap(),
        where: 'id = ?', whereArgs: [materia.id]);
  }

  Future<void> eliminarMateria(int id) async {
    final db = await database;
    await db.delete('materias', where: 'id = ?', whereArgs: [id]);
    await db.delete('tareas', where: 'materiaId = ?', whereArgs: [id]);
  }

  // ---------- TAREAS ----------

  Future<int> crearTarea(Tarea tarea) async {
    final db = await database;
    return await db.insert('tareas', tarea.toMap()..remove('id'));
  }

  Future<List<Tarea>> obtenerTareas() async {
    final db = await database;
    final result = await db.query('tareas');
    return result.map((t) => Tarea.fromMap(t)).toList();
  }

  Future<void> actualizarTarea(Tarea tarea) async {
    final db = await database;
    await db.update('tareas', tarea.toMap(),
        where: 'id = ?', whereArgs: [tarea.id]);
  }

  Future<void> eliminarTarea(int id) async {
    final db = await database;
    await db.delete('tareas', where: 'id = ?', whereArgs: [id]);
  }
}
