import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Service: abre o SQLite no Chrome, cria a tabela e insere as amostras.
// Não contém regras de formulário nem widgets.
class DatabaseService {
  Database? _banco;
  Future<Database>? _abertura;

  static const amostras = <Map<String, Object?>>[
    {'nome': 'Roteiro do evento', 'paginas': 4, 'copias': 3, 'impresso': 0},
    {'nome': 'Cartaz da oficina', 'paginas': 2, 'copias': 5, 'impresso': 0},
    {'nome': 'Lista de presença', 'paginas': 1, 'copias': 2, 'impresso': 1},
  ];

  Future<Database> get banco {
    if (_banco != null) return Future.value(_banco!);
    return _abertura ??= _abrir();
  }

  Future<Database> _abrir() async {
    try {
      final db = await databaseFactoryFfiWeb.openDatabase(
        'fila_impressao_modular_alunos_v1.db',
        options: OpenDatabaseOptions(version: 1, onCreate: (db, versao) async {
          await db.execute('CREATE TABLE documentos ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'nome TEXT NOT NULL, paginas INTEGER NOT NULL, '
            'copias INTEGER NOT NULL, impresso INTEGER NOT NULL DEFAULT 0)');
          for (final documento in amostras) {
            await db.insert('documentos', documento);
          }
        }),
      );
      _banco = db;
      return db;
    } catch (_) {
      _abertura = null;
      rethrow;
    }
  }
}
