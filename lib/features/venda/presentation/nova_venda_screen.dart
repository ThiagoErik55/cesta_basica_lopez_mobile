import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../cliente/data/cliente_repository.dart';
import '../../cliente/presentation/cliente_providers.dart';
import '../domain/rotulos_venda.dart';
import 'nova_venda_providers.dart';
import 'rodape_venda.dart';
import 'secao_cliente_venda.dart';
import 'secao_pagamento_venda.dart';
import 'secao_produtos_venda.dart';
import 'selecionar_cliente_sheet.dart';

/// Nova venda (RF10, RF12, RF13, RF14, RF23), aberta pelo botão central
/// da navegação ou pela tela do cliente.
///
/// - KAN-24: seleção de cliente com alerta de pendência
/// - KAN-25: listagem de produtos e carrinho
/// - KAN-26: forma de pagamento (à vista ou parcelado)
/// - KAN-27: finalizar e gravar o pedido
///
/// [clienteIdInicial] já deixa o cliente selecionado (vindo dos detalhes
/// do cliente).
class NovaVendaScreen extends ConsumerStatefulWidget {
  const NovaVendaScreen({this.clienteIdInicial, super.key});

  final String? clienteIdInicial;

  @override
  ConsumerState<NovaVendaScreen> createState() => _NovaVendaScreenState();
}

class _NovaVendaScreenState extends ConsumerState<NovaVendaScreen> {
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    final id = widget.clienteIdInicial;
    if (id != null) _carregarClienteInicial(id);
  }

  Future<void> _carregarClienteInicial(String id) async {
    final cliente = await ref.read(clienteRepositoryProvider).buscarPorId(id);
    if (!mounted || cliente == null) return;
    ref.read(novaVendaProvider.notifier).selecionarCliente(cliente);
  }

  Future<void> _escolherCliente() async {
    final cliente = await selecionarCliente(context);
    if (!mounted || cliente == null) return;
    ref.read(novaVendaProvider.notifier).selecionarCliente(cliente);
  }

  Future<void> _finalizar() async {
    final venda = ref.read(novaVendaProvider);
    final mensageiro = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    final impedimento = venda.impedimento;
    if (impedimento != null) {
      mensageiro.showSnackBar(SnackBar(content: Text(impedimento)));
      return;
    }

    final pendencia = venda.pendencia;
    if (venda.parcelado && (pendencia?.exigeAprovacaoParcelado ?? false)) {
      final aprovado = await confirmar(
        context,
        titulo: 'Aprovação do gerente',
        mensagem:
            '${pendencia!.mensagens.join('\n\n')}\n\n'
            'Confirme que a venda parcelada foi aprovada.',
        textoConfirmar: 'Aprovada',
      );
      if (!aprovado || !mounted) return;
    }

    setState(() => _finalizando = true);
    try {
      final resultado = await ref.read(novaVendaProvider.notifier).finalizar();
      if (!mounted) return;
      ref.invalidate(clientePorIdProvider(resultado.venda.clienteId));
      final vendaId = resultado.venda.id;
      // Nota e assinatura são geradas e gravadas no aparelho, então as
      // duas ações funcionam mesmo offline.
      mensageiro.showSnackBar(
        SnackBar(
          // Tempo para dar para tocar nas ações antes de a mensagem sumir.
          duration: const Duration(seconds: 10),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resultado.sincronizado
                    ? 'Venda registrada.'
                    : 'Venda salva no aparelho. Será enviada quando houver '
                          'conexão.',
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final (rotulo, rota) in [
                    ('Ver nota', AppRoutes.notaProvisoria),
                    ('Coletar assinatura', AppRoutes.assinatura),
                  ])
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .inversePrimary,
                      ),
                      onPressed: () {
                        mensageiro.hideCurrentSnackBar();
                        navegador.pushNamed(rota, arguments: vendaId);
                      },
                      child: Text(rotulo),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
      navegador.pushReplacementNamed(
        AppRoutes.detalheVenda,
        arguments: resultado.venda.id,
      );
    } catch (e) {
      debugPrint('Erro ao finalizar venda: $e');
      if (!mounted) return;
      setState(() => _finalizando = false);
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a venda. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venda = ref.watch(novaVendaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Venda'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SecaoClienteVenda(venda: venda, onEscolher: _escolherCliente),
          const SizedBox(height: AppSpacing.lg),
          const SecaoProdutosVenda(),
          const SizedBox(height: AppSpacing.lg),
          SecaoPagamentoVenda(venda: venda),
        ],
      ),
      bottomNavigationBar: RodapeVenda(
        total: venda.total,
        unidades: venda.unidades,
        descricaoPagamento: _descricaoPagamento(venda),
        avisoEstoque: venda.avisoEstoque,
        finalizando: _finalizando,
        onFinalizar: _finalizar,
      ),
    );
  }

  String? _descricaoPagamento(NovaVendaState venda) =>
      switch (venda.pagamento) {
        PagamentoAVista(:final forma) => forma.rotulo,
        PagamentoParcelado() => 'Parcelado em ${venda.numeroParcelas}x',
        null => null,
      };
}
