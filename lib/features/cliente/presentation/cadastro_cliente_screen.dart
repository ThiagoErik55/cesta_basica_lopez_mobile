import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../data/cliente_model.dart';
import '../domain/dados_cadastrais_cliente.dart';
import 'cliente_form.dart';
import 'cliente_providers.dart';

/// Cadastro (RF01) e edição (KAN-17) dos dados cadastrais do cliente.
/// Sem [cliente], cadastra um novo; com [cliente], edita esse cliente.
/// Score, limite de crédito e bloqueado não são editados aqui.
class CadastroClienteScreen extends ConsumerWidget {
  const CadastroClienteScreen({this.cliente, super.key});

  final ClienteModel? cliente;

  bool get _editando => cliente != null;

  Future<void> _salvar(
    BuildContext context,
    WidgetRef ref,
    DadosCadastraisCliente dados,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(salvarClienteProvider.notifier);
    final mensagem = _editando ? 'Cliente atualizado.' : 'Cliente cadastrado.';

    try {
      final sincronizado = _editando
          ? await notifier.atualizar(cliente!, dados)
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
          content: Text('Não foi possível salvar o cliente. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salvando = ref.watch(salvarClienteProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Cliente' : 'Novo Cliente'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: ClienteForm(
        inicial: cliente,
        textoBotao: _editando ? 'Salvar alterações' : 'Salvar',
        salvando: salvando,
        onSalvar: (dados) => _salvar(context, ref, dados),
      ),
    );
  }
}
