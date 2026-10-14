import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/venda_model.dart';
import '../domain/rotulos_venda.dart';
import 'pos_venda_providers.dart';

/// Detalhes de uma venda registrada (KAN-27): itens, pagamento e
/// parcelas.
///
/// Recebe o id da venda como argumento da rota.
class DetalhesVendaScreen extends ConsumerWidget {
  const DetalhesVendaScreen({required this.vendaId, super.key});

  final String vendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venda = ref.watch(vendaPorIdProvider(vendaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Venda'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: venda.when(
        data: (v) => v == null
            ? const Center(
                child: EmptyState(
                  icone: Icons.receipt_long_outlined,
                  titulo: 'Venda não encontrada',
                  descricao: 'Ela pode ter sido removida.',
                ),
              )
            : _Detalhes(venda: v),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar venda $vendaId: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar venda',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.venda});

  final VendaModel venda;

  @override
  Widget build(BuildContext context) {
    final pagamento = venda.formaPagamento?.rotulo ?? venda.tipo.rotulo;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Nota ${venda.numeroNota}', style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${venda.clienteNome} · ${formatarData(venda.data)}',
          style: AppTextStyles.cardSubtitle,
        ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(titulo: 'Itens'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final item in venda.itens)
                  _Linha(
                    titulo: '${item.quantidade}x ${item.nome}',
                    detalhe: '${formatarMoeda(item.precoUnitario)} cada',
                    valor: formatarMoeda(item.subtotal),
                  ),
                const Divider(color: AppColors.border),
                _Linha(
                  titulo: 'Total',
                  detalhe: pagamento,
                  valor: formatarMoeda(venda.valorTotal),
                  destaque: true,
                ),
              ],
            ),
          ),
        ),

        if (venda.ehPromissoria) ...[
          const SizedBox(height: AppSpacing.lg),
          _Parcelas(vendaId: venda.id),
        ],
      ],
    );
  }
}

class _Parcelas extends ConsumerWidget {
  const _Parcelas({required this.vendaId});

  final String vendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelas = ref.watch(parcelasDaVendaProvider(vendaId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(titulo: 'Parcelas'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: parcelas.when(
              data: (lista) => Column(
                children: [
                  for (final p in lista)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.numero}ª · ${formatarData(p.vencimento)}',
                              style: AppTextStyles.body,
                            ),
                          ),
                          if (p.pago)
                            const StatusBadge.emDia()
                          else if (p.atrasada)
                            const StatusBadge.vencido(),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatarMoeda(p.valor),
                            style: AppTextStyles.money,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao carregar parcelas: $error');
                return const Text(
                  'Erro ao carregar parcelas.',
                  style: AppTextStyles.body,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.titulo,
    required this.detalhe,
    required this.valor,
    this.destaque = false,
  });

  final String titulo;
  final String detalhe;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.cardTitle),
                Text(detalhe, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            valor,
            style: destaque ? AppTextStyles.money : AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
