import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../venda/domain/historico_financeiro.dart';
import '../../venda/domain/rotulos_venda.dart';
import '../../venda/presentation/comprovante_providers.dart';
import '../../venda/presentation/historico_financeiro_providers.dart';

/// Histórico de compras do cliente (KAN-18): vendas reais, da mais
/// recente para a mais antiga. Cada compra abre os detalhes da venda,
/// onde ficam parcelas, troca (KAN-28) e observações (KAN-29).
class HistoricoComprasSecao extends ConsumerWidget {
  const HistoricoComprasSecao({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoFinanceiroProvider(clienteId));

    return _SecaoHistorico(
      titulo: 'Histórico de Compras',
      acao: TextButton.icon(
        onPressed: () =>
            Navigator.of(context)
                .pushNamed(AppRoutes.novaVenda, arguments: clienteId),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nova venda'),
      ),
      historico: historico,
      vazio: const EmptyState(
        icone: Icons.receipt_long_outlined,
        titulo: 'Nenhuma compra',
        descricao: 'As compras do cliente aparecem aqui.',
      ),
      erro: 'Erro ao carregar compras.',
      itens: (h) => [
        for (final compra in h.compras)
          _ItemHistorico(
            titulo: 'Nota ${compra.venda.numeroNota}',
            detalhe:
                '${formatarData(compra.venda.data)} · '
                '${compra.venda.tipo.rotulo} · ${compra.situacao.rotulo}'
                '${compra.venda.trocas.isEmpty ? '' : ' · com troca'}',
            valor: compra.venda.valorTotal,
            vendaId: compra.venda.id,
            // Nota provisória da compra (KAN-37).
            comNota: true,
          ),
      ],
    );
  }
}

/// Histórico de pagamentos do cliente (KAN-19): recebimentos reais, do
/// mais recente para o mais antigo, com a parcela e a venda de origem.
class HistoricoPagamentosSecao extends ConsumerWidget {
  const HistoricoPagamentosSecao({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoFinanceiroProvider(clienteId));

    return _SecaoHistorico(
      titulo: 'Histórico de Pagamentos',
      historico: historico,
      vazio: const EmptyState(
        icone: Icons.payments_outlined,
        titulo: 'Nenhum pagamento',
        descricao: 'Os pagamentos do cliente aparecem aqui.',
      ),
      erro: 'Erro ao carregar pagamentos.',
      itens: (h) => [
        for (final item in h.pagamentos)
          _ItemHistorico(
            titulo: 'Parcela ${item.numeroParcela} · Nota ${item.numeroNota}',
            detalhe:
                '${formatarData(item.pagamento.data)} · '
                '${item.pagamento.forma.rotulo}'
                '${(item.pagamento.observacao?.isEmpty ?? true) ? '' : ' · ${item.pagamento.observacao}'}',
            valor: item.pagamento.valor,
            vendaId: item.vendaId,
            // Comprovante do pagamento (KAN-36).
            comprovante: ComprovanteArgs(
              vendaId: item.vendaId,
              parcelaId: item.parcelaId,
              pagamentoId: item.pagamento.id,
            ),
          ),
      ],
    );
  }
}

/// Cabeçalho e um card com os itens, o estado vazio, o carregamento ou
/// o erro.
class _SecaoHistorico extends StatelessWidget {
  const _SecaoHistorico({
    required this.titulo,
    required this.historico,
    required this.vazio,
    required this.erro,
    required this.itens,
    this.acao,
  });

  final String titulo;
  final Widget? acao;
  final AsyncValue<HistoricoFinanceiro> historico;
  final Widget vazio;
  final String erro;
  final List<Widget> Function(HistoricoFinanceiro) itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(titulo: titulo, acao: acao),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: historico.when(
              data: (h) {
                final lista = itens(h);
                if (lista.isEmpty) return vazio;
                return Column(
                  children: [
                    for (final (i, item) in lista.indexed) ...[
                      if (i > 0)
                        const Divider(
                          height: AppSpacing.lg,
                          color: AppColors.border,
                        ),
                      item,
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                // Erro comum: índice composto ausente no Firestore (ver
                // firestore.indexes.json).
                debugPrint('$erro $e');
                return Text(erro, style: AppTextStyles.body);
              },
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
    required this.vendaId,
    this.comprovante,
    this.comNota = false,
  });

  final String titulo;
  final String detalhe;
  final double valor;
  final String vendaId;

  /// Quando informado, mostra a ação que abre o comprovante.
  final ComprovanteArgs? comprovante;

  /// Mostra a ação que abre a nota provisória da venda.
  final bool comNota;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(AppRoutes.detalheVenda, arguments: vendaId),
      child: Row(
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
          if (comprovante case final args?)
            IconButton(
              tooltip: 'Comprovante',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .pushNamed(AppRoutes.comprovante, arguments: args),
            ),
          if (comNota)
            IconButton(
              tooltip: 'Nota provisória',
              icon: const Icon(Icons.description_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .pushNamed(AppRoutes.notaProvisoria, arguments: vendaId),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
