import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../data/produto_model.dart';
import '../domain/dados_cadastrais_produto.dart';
import 'produto_form.dart';
import 'produto_providers.dart';

/// Cadastro e edição dos dados do produto (KAN-23). Sem [produto],
/// cadastra um novo; com [produto], edita esse produto.
class CadastroProdutoScreen extends ConsumerWidget {
  const CadastroProdutoScreen({this.produto, super.key});

  final ProdutoModel? produto;

  bool get _editando => produto != null;

  Future<void> _salvar(
    BuildContext context,
    WidgetRef ref,
    DadosCadastraisProduto dados,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(salvarProdutoProvider.notifier);
    final mensagem = _editando ? 'Produto atualizado.' : 'Produto cadastrado.';

    try {
      final sincronizado = _editando
          ? await notifier.atualizar(produto!, dados)
          : await notifier.cadastrar(dados);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? mensagem
                : '$mensagem Será sincronizado quando houver conexão.',
          ),
        ),
      );
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o produto. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salvando = ref.watch(salvarProdutoProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Produto' : 'Novo Produto'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: ProdutoForm(
        inicial: produto,
        textoBotao: _editando ? 'Salvar alterações' : 'Salvar',
        salvando: salvando,
        onSalvar: (dados) => _salvar(context, ref, dados),
      ),
    );
  }
}
