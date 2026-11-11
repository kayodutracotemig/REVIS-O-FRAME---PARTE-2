import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../lib/pages/impressao_page.dart';
import '../lib/providers/impressao_provider.dart';
import '../lib/repositories/impressao_repository.dart';
import '../lib/services/database_service.dart';

// Repositório em memória para conferir as regras do Provider sem substituir o SQLite do app.
class RepositorioTeste extends ImpressaoRepository {
  RepositorioTeste(List<Map<String, Object?>> iniciais)
      : documentos =
            iniciais.map((item) => Map<String, Object?>.from(item)).toList(),
        super(DatabaseService());

  final List<Map<String, Object?>> documentos;
  int gravacoes = 0;

  @override
  Future<List<Map<String, Object?>>> listar() async => documentos
      .map((documento) => Map<String, Object?>.from(documento))
      .toList();

  @override
  Future<void> salvar({
    int? id,
    required String nome,
    required int paginas,
    required int copias,
  }) async {
    gravacoes++;
    if (id == null) {
      final novoId = documentos.isEmpty
          ? 1
          : documentos
                  .map((item) => item['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      documentos.add({
        'id': novoId,
        'nome': nome,
        'paginas': paginas,
        'copias': copias,
        'impresso': 0,
      });
    } else {
      final item = documentos.firstWhere((item) => item['id'] == id);
      item.addAll({'nome': nome, 'paginas': paginas, 'copias': copias});
    }
  }

  @override
  Future<void> alternarImpressao(int id, bool estavaImpresso) async {
    final item = documentos.firstWhere((item) => item['id'] == id);
    item['impresso'] = estavaImpresso ? 0 : 1;
  }

  @override
  Future<void> excluir(int id) async {
    documentos.removeWhere((documento) => documento['id'] == id);
  }
}

List<Map<String, Object?>> amostrasTeste() => [
      {
        'id': 1,
        'nome': 'Roteiro do evento',
        'paginas': 4,
        'copias': 3,
        'impresso': 0,
      },
      {
        'id': 2,
        'nome': 'Cartaz da oficina',
        'paginas': 2,
        'copias': 5,
        'impresso': 0,
      },
      {
        'id': 3,
        'nome': 'Lista de presença',
        'paginas': 1,
        'copias': 2,
        'impresso': 1,
      },
    ];

void main() {
  // Confere a regra de cálculo por documento e o resumo, mesmo quando há filtro ativo.
  test('calcula folhas por multiplicação e mantém resumo geral', () async {
    final repo = RepositorioTeste(amostrasTeste());
    final provider = ImpressaoProvider(repo);
    addTearDown(provider.dispose);
    await provider.iniciar();

    expect(provider.documentosVisiveis.map((d) => d['nome']).toList(), [
      'Roteiro do evento',
      'Cartaz da oficina',
      'Lista de presença',
    ]);
    expect(provider.folhasDoDocumento(provider.documentosVisiveis.first), 12);
    expect(provider.folhasDoDocumento(provider.documentosVisiveis[1]), 10);
    expect(provider.folhasDoDocumento(provider.documentosVisiveis[2]), 2);
    expect(provider.totalFolhas, 24);
    expect(provider.totalDocumentos, 3);

    provider.alterarFiltro('Pendentes');
    expect(provider.totalFolhas, 24);
  });

  // Garante que cada opção de filtro seleciona o estado correto de impressão.
  test('mostra somente pendentes ou somente impressos', () async {
    final provider = ImpressaoProvider(RepositorioTeste(amostrasTeste()));
    addTearDown(provider.dispose);
    await provider.iniciar();

    provider.alterarFiltro('Pendentes');
    expect(provider.documentosVisiveis.map((d) => d['nome']).toList(), [
      'Roteiro do evento',
      'Cartaz da oficina',
    ]);
    provider.alterarFiltro('Impressos');
    expect(provider.documentosVisiveis.map((d) => d['nome']).toList(), [
      'Lista de presença',
    ]);
  });

  // Zeros precisam ser recusados antes de chamar a persistência, também durante edição.
  test('recusa zero em páginas ou cópias no cadastro e na edição', () async {
    final repo = RepositorioTeste(amostrasTeste());
    final provider = ImpressaoProvider(repo);
    addTearDown(provider.dispose);
    await provider.iniciar();

    expect(
      await provider.salvar(nome: 'Novo', paginasTexto: '0', copiasTexto: '2'),
      isFalse,
    );
    expect(
      await provider.salvar(nome: 'Novo', paginasTexto: '2', copiasTexto: '0'),
      isFalse,
    );
    expect(
      await provider.salvar(
        id: 1,
        nome: 'Roteiro do evento',
        paginasTexto: '0',
        copiasTexto: '3',
      ),
      isFalse,
    );
    expect(
      await provider.salvar(nome: 'Novo', paginasTexto: '-1', copiasTexto: '2'),
      isFalse,
    );
    expect(
      await provider.salvar(
          nome: 'Novo', paginasTexto: '1.5', copiasTexto: '2'),
      isFalse,
    );
    expect(repo.gravacoes, 0);
  });

  // Cadastro novo deve manter sua posição no final da fila após recarregar.
  test('acrescenta documentos novos ao final da fila', () async {
    final provider = ImpressaoProvider(RepositorioTeste(amostrasTeste()));
    addTearDown(provider.dispose);
    await provider.iniciar();

    expect(
      await provider.salvar(
          nome: 'Documento novo', paginasTexto: '1', copiasTexto: '1'),
      isTrue,
    );
    expect(provider.documentosVisiveis.last['nome'], 'Documento novo');
  });

  // Cadastro, edição e exclusão continuam restritos ao documento indicado.
  test('edita e exclui somente o documento selecionado', () async {
    final provider = ImpressaoProvider(RepositorioTeste(amostrasTeste()));
    addTearDown(provider.dispose);
    await provider.iniciar();

    expect(
      await provider.salvar(
        id: 2,
        nome: 'Cartaz atualizado',
        paginasTexto: '3',
        copiasTexto: '4',
      ),
      isTrue,
    );
    expect(provider.documentosVisiveis.map((d) => d['nome']).toList(), [
      'Roteiro do evento',
      'Cartaz atualizado',
      'Lista de presença',
    ]);
    expect(await provider.excluir(2), isTrue);
    expect(provider.documentosVisiveis.map((d) => d['id']).toList(), [1, 3]);
  });

  // O toggle deve mudar apenas o ID escolhido e permitir desfazer a marcação.
  test('alternar impressão modifica apenas o documento selecionado', () async {
    final repo = RepositorioTeste(amostrasTeste());
    final provider = ImpressaoProvider(repo);
    addTearDown(provider.dispose);
    await provider.iniciar();

    await provider.alternar(provider.documentosVisiveis.first);
    expect(provider.documentosVisiveis.map((d) => d['impresso']).toList(), [
      1,
      0,
      1,
    ]);
    await provider.alternar(provider.documentosVisiveis.first);
    expect(provider.documentosVisiveis.map((d) => d['impresso']).toList(), [
      0,
      0,
      1,
    ]);
    final reloadedProvider = ImpressaoProvider(repo);
    addTearDown(reloadedProvider.dispose);
    await reloadedProvider.iniciar();
    expect(
        reloadedProvider.documentosVisiveis.map((d) => d['impresso']).toList(),
        [
          0,
          0,
          1,
        ]);
  });

  // Simula dois tamanhos de celular e verifica que campos, ações e fila cabem sem overflow.
  for (final tamanho in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets(
      'interface responsiva em ${tamanho.width}×${tamanho.height}',
      (tester) async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = ImpressaoProvider(RepositorioTeste(amostrasTeste()));
        addTearDown(provider.dispose);
        await provider.iniciar();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(home: ImpressaoPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNWidgets(3));
        expect(find.text('Salvar'), findsOneWidget);
        expect(find.text('Roteiro do evento'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
