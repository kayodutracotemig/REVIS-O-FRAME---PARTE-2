import 'package:flutter/foundation.dart';

import '../repositories/impressao_repository.dart';

// Provider: guarda o estado, aplica regras e avisa a tela com notifyListeners.
class ImpressaoProvider extends ChangeNotifier {
  final ImpressaoRepository repository;
  ImpressaoProvider(this.repository);

  List<Map<String, Object?>> _documentos = [];
  bool _carregando = false;
  bool _descartado = false;
  String _filtro = 'Todos';
  String? _falhaBanco;
  String? _mensagem;

  bool get carregando => _carregando;
  String get filtro => _filtro;
  String? get falhaBanco => _falhaBanco;
  String? get mensagem => _mensagem;
  int get totalDocumentos => _documentos.length;

  // Retorna uma lista derivada; a lista completa é mantida para o resumo.
  List<Map<String, Object?>> get documentosVisiveis =>
      _documentos.where(_mostrar).toList();

  bool _mostrar(Map<String, Object?> documento) {
    final impresso = documento['impresso'] as int;
    // Pendentes são os documentos cuja impressão ainda não foi concluída.
    if (_filtro == 'Pendentes') return impresso == 0;
    if (_filtro == 'Impressos') return impresso == 1;
    return true;
  }

  int folhasDoDocumento(Map<String, Object?> documento) {
    final paginas = documento['paginas'] as int;
    final copias = documento['copias'] as int;
    // Cada cópia consome uma folha por página, pois a impressão é só frente.
    return paginas * copias;
  }

  int get totalFolhas => _documentos.fold<int>(
    0,
    (soma, documento) =>
        soma + (documento['paginas'] as int) * (documento['copias'] as int),
  );

  void alterarFiltro(String valor) {
    _filtro = valor;
    _notificar();
  }

  String? validar(String nome, int? paginas, int? copias) {
    if (nome.trim().isEmpty) return 'Preencha o nome do documento.';
    if (paginas == null || copias == null)
      return 'Informe números inteiros positivos.';
    // Zero não é uma quantidade válida nem ao criar nem ao editar documentos.
    if (paginas <= 0 || copias <= 0)
      return 'Páginas e cópias devem ser maiores que zero.';
    return null;
  }

  Future<void> _atualizarDados() async {
    _documentos = await repository.listar();
  }

  Future<bool> iniciar() async {
    _falhaBanco = null;
    final sucesso = await _executar(_atualizarDados);
    if (!sucesso) _falhaBanco = _mensagem;
    _notificar();
    return sucesso;
  }

  Future<bool> recarregar() => _executar(_atualizarDados);

  Future<bool> salvar({
    int? id,
    required String nome,
    required String paginasTexto,
    required String copiasTexto,
  }) async {
    final paginas = int.tryParse(paginasTexto.trim());
    final copias = int.tryParse(copiasTexto.trim());
    final erro = validar(nome, paginas, copias);
    if (erro != null) {
      _mensagem = erro;
      _notificar();
      return false;
    }
    return _executar(() async {
      await repository.salvar(
        id: id,
        nome: nome,
        paginas: paginas!,
        copias: copias!,
      );
      await _atualizarDados();
    });
  }

  Future<bool> alternar(Map<String, Object?> documento) => _executar(() async {
    await repository.alternarImpressao(
      documento['id'] as int,
      documento['impresso'] == 1,
    );
    await _atualizarDados();
  });

  Future<bool> excluir(int id) => _executar(() async {
    await repository.excluir(id);
    await _atualizarDados();
  });

  Future<bool> restaurar() => _executar(() async {
    await repository.restaurarAmostras();
    await _atualizarDados();
  });

  Future<bool> _executar(Future<void> Function() operacao) async {
    if (_carregando) return false;
    _carregando = true;
    _mensagem = null;
    _notificar();
    try {
      await operacao();
      return true;
    } catch (erro) {
      _mensagem = 'Não foi possível concluir: $erro';
      return false;
    } finally {
      _carregando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
