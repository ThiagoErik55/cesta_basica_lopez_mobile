// ============================================================================
// ⚠️ PROVISÓRIO (KAN-18, KAN-19) — exibe DADOS FICTÍCIOS
//
// O layout destas seções é o definitivo, mas a fonte de dados não: hoje vem
// de historico_mock_providers.dart. Quando VENDA e PAGAMENTO existirem
// (Sprint 4/5), trocar CompraMock/PagamentoMock pelos modelos reais, os
// providers pelos repositórios reais, e remover o selo "Dados fictícios".
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import 'historico_mock_providers.dart';

/// Histórico de compras do cliente (KAN-18).
class HistoricoComprasSecao extends ConsumerWidget {
  const HistoricoComprasSecao({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compras = ref.watch(comprasMockProvider(clienteId));

    return _SecaoHistorico(
      titulo: 'Histórico de Compras',
      vazio: const EmptyState(
        icone: Icons.receipt_long_outlined,
        titulo: 'Nenhuma compra',
        descricao: 'As compras do cliente aparecem aqui.',
      ),
      itens: [
        for (final compra in compras)
          _ItemHistorico(
            titulo: 'Nota ${compra.numeroNota}',
            detalhe:
                '${formatarData(compra.data)} · ${_rotuloTipo(compra.tipo)}',
            valor: compra.valorTotal,
          ),
      ],
    );
  }
}

/// Histórico de pagamentos do cliente (KAN-19).
class HistoricoPagamentosSecao extends ConsumerWidget {
  const HistoricoPagamentosSecao({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagamentos = ref.watch(pagamentosMockProvider(clienteId));

    return _SecaoHistorico(
      titulo: 'Histórico de Pagamentos',
      vazio: const EmptyState(
        icone: Icons.payments_outlined,
        titulo: 'Nenhum pagamento',
        descricao: 'Os pagamentos do cliente aparecem aqui.',
      ),
      itens: [
        for (final pagamento in pagamentos)
          _ItemHistorico(
            titulo: 'Parcela ${pagamento.numeroParcela}',
            detalhe:
                '${formatarData(pagamento.data)} · '
                '${_rotuloForma(pagamento.formaPagamento)}',
            valor: pagamento.valor,
          ),
      ],
    );
  }
}

/// Cabeçalho com o selo de dados fictícios e um card com os itens, ou o
/// estado vazio.
class _SecaoHistorico extends StatelessWidget {
  const _SecaoHistorico({
    required this.titulo,
    required this.vazio,
    required this.itens,
  });

  final String titulo;
  final Widget vazio;
  final List<Widget> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          titulo: titulo,
          // Deixa claro na tela (e na Pré-Banca) que não são dados reais.
          acao: const StatusBadge('Dados fictícios', AppColors.offline),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: itens.isEmpty
                ? vazio
                : Column(
                    children: [
                      for (final (i, item) in itens.indexed) ...[
                        if (i > 0)
                          const Divider(
                            height: AppSpacing.lg,
                            color: AppColors.border,
                          ),
                        item,
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({
    required this.titulo,
    required this.detalhe,
    required this.valor,
  });

  final String titulo;
  final String detalhe;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(detalhe, style: AppTextStyles.cardSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(formatarMoeda(valor), style: AppTextStyles.money),
      ],
    );
  }
}

String _rotuloTipo(TipoVenda tipo) => switch (tipo) {
  TipoVenda.aVista => 'À vista',
  TipoVenda.parcelado => 'Parcelado',
};

String _rotuloForma(FormaPagamento forma) => switch (forma) {
  FormaPagamento.pix => 'Pix',
  FormaPagamento.credito => 'Cartão de crédito',
  FormaPagamento.debito => 'Cartão de débito',
  FormaPagamento.valeAlimentacao => 'Vale-alimentação',
  FormaPagamento.dinheiro => 'Dinheiro',
};
