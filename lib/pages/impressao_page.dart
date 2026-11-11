import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/impressao_provider.dart';

// Page: mostra o formulário e a lista; encaminha ações para o Provider.
class ImpressaoPage extends StatefulWidget {
  const ImpressaoPage({super.key});
  @override
  State<ImpressaoPage> createState() => _ImpressaoPageState();
}

class _ImpressaoPageState extends State<ImpressaoPage> {
  final nome = TextEditingController();
  final paginas = TextEditingController();
  final copias = TextEditingController();
  int? idEdicao;

  @override
  void dispose() {
    nome.dispose();
    paginas.dispose();
    copias.dispose();
    super.dispose();
  }

  void limpar() {
    nome.clear();
    paginas.clear();
    copias.clear();
    idEdicao = null;
  }

  void avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> salvar() async {
    final provider = context.read<ImpressaoProvider>();
    final sucesso = await provider.salvar(
      id: idEdicao,
      nome: nome.text,
      paginasTexto: paginas.text,
      copiasTexto: copias.text,
    );
    if (!mounted) return;
    if (sucesso) {
      setState(limpar);
      avisar('Documento salvo.');
    } else {
      avisar(provider.mensagem ?? 'Não foi possível salvar.');
    }
  }

  Future<void> alternar(Map<String, Object?> documento) async {
    final provider = context.read<ImpressaoProvider>();
    final sucesso = await provider.alternar(documento);
    if (!mounted) return;
    if (!sucesso) avisar(provider.mensagem ?? 'Não foi possível alterar.');
  }

  Future<bool> confirmar(String titulo, String texto) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> excluir(Map<String, Object?> documento) async {
    if (!await confirmar('Excluir documento?', documento['nome'] as String))
      return;
    if (!mounted) return;
    final provider = context.read<ImpressaoProvider>();
    final sucesso = await provider.excluir(documento['id'] as int);
    if (!mounted) return;
    if (sucesso && idEdicao == documento['id']) setState(limpar);
    if (!sucesso) avisar(provider.mensagem ?? 'Não foi possível excluir.');
  }

  Future<void> restaurar() async {
    if (!await confirmar(
      'Restaurar amostras?',
      'Os documentos atuais desta atividade serão substituídos pelas três amostras.',
    ))
      return;
    if (!mounted) return;
    final provider = context.read<ImpressaoProvider>();
    final sucesso = await provider.restaurar();
    if (!mounted) return;
    if (sucesso) setState(limpar);
    if (!sucesso) avisar(provider.mensagem ?? 'Não foi possível restaurar.');
  }

  Future<void> recarregar() async {
    final provider = context.read<ImpressaoProvider>();
    final sucesso = await provider.recarregar();
    if (!mounted) return;
    if (!sucesso) avisar(provider.mensagem ?? 'Não foi possível recarregar.');
  }

  Widget campo(
    TextEditingController controller,
    String titulo, {
    bool numero = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: numero ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: titulo,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // watch faz a tela acompanhar as notificações do Provider.
    final provider = context.watch<ImpressaoProvider>();
    if (provider.falhaBanco != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuração')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Não foi possível abrir o banco. Confira a preparação web.',
              ),
              SelectableText(provider.falhaBanco!),
              FilledButton(
                onPressed: provider.carregando
                    ? null
                    : () {
                        provider.iniciar();
                      },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    final documentos = provider.documentosVisiveis;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de impressão'),
        actions: [
          IconButton(
            tooltip: 'Recarregar do banco',
            onPressed: provider.carregando ? null : recarregar,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Restaurar amostras',
            onPressed: provider.carregando ? null : restaurar,
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: provider.carregando,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.carregando) const LinearProgressIndicator(),
                  Text(
                    idEdicao == null ? 'Novo documento' : 'Editar documento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  campo(nome, 'Documento'),
                  campo(paginas, 'Páginas por cópia', numero: true),
                  campo(copias, 'Cópias', numero: true),
                  // Wrap permite que o botão de edição cancelável caiba em telas estreitas.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: salvar,
                        child: const Text('Salvar'),
                      ),
                      if (idEdicao != null)
                        TextButton(
                          onPressed: () => setState(limpar),
                          child: const Text('Cancelar edição'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Documentos: ${provider.totalDocumentos} | Folhas necessárias: ${provider.totalFolhas}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: provider.filtro,
                    isExpanded: true,
                    items: ['Todos', 'Pendentes', 'Impressos']
                        .map(
                          (opcao) => DropdownMenuItem(
                            value: opcao,
                            child: Text(opcao),
                          ),
                        )
                        .toList(),
                    onChanged: (opcao) {
                      if (opcao != null) provider.alterarFiltro(opcao);
                    },
                  ),
                  if (documentos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Nenhum documento para este filtro.'),
                    ),
                  ...documentos.map(
                    (documento) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              documento['nome'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Páginas por cópia: ${documento['paginas']} | Cópias: ${documento['copias']}',
                            ),
                            Text(
                              'Folhas necessárias: ${provider.folhasDoDocumento(documento)}',
                            ),
                            Text(
                              'Impresso: ${documento['impresso'] == 1 ? 'Sim' : 'Não'}',
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => alternar(documento),
                                  child: const Text('Alternar impressão'),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    idEdicao = documento['id'] as int;
                                    nome.text = documento['nome'] as String;
                                    paginas.text = documento['paginas']
                                        .toString();
                                    copias.text = documento['copias']
                                        .toString();
                                  }),
                                  child: const Text('Editar'),
                                ),
                                TextButton(
                                  onPressed: () => excluir(documento),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
