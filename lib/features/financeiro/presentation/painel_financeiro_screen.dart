import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/agregacao_financeira.dart';
import 'grafico_evolucao.dart';
import 'painel_detalhes.dart';
import 'painel_indicadores.dart';
import 'painel_providers.dart';
import 'seletor_periodo.dart';

/// Painel financeiro por período (RF29, KAN-52): indicadores, comparação
/// com o período anterior, evolução diária e detalhamento.
class PainelFinanceiroScreen extends ConsumerWidget {
  const PainelFinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painel = ref.watch(painelFinanceiroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel financeiro'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: Column(
        children: [
          const SeletorPeriodo(),
          Expanded(
            child: painel.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao montar o painel financeiro: $error');
                return const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao carregar o painel',
                    descricao: 'Verifique a conexão e tente novamente.',
                  ),
                );
              },
              data: (p) => _Conteudo(painel: p),
            ),
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.painel});

  final PainelFinanceiro painel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recebiveis = ref.watch(posicaoRecebiveisProvider).value;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (painel.totais.vazio) ...[
          Text(
            'Sem vendas nem despesas neste período. Os indicadores '
            'aparecem zerados.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusAtencao,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PainelIndicadores(painel: painel, recebiveis: recebiveis),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(titulo: 'Evolução diária'),
        const SizedBox(height: AppSpacing.sm),
        GraficoEvolucao(serie: painel.serie),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(titulo: 'Despesas por dia'),
        const SizedBox(height: AppSpacing.sm),
        DespesasPorDia(dias: painel.despesasPorDia),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(titulo: 'Mais vendidos'),
        const SizedBox(height: AppSpacing.sm),
        TopProdutos(produtos: painel.topProdutos),
      ],
    );
  }
}
