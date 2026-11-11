import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/recomendacao_visita.dart';
import 'recomendacao_providers.dart';
import 'recomendacoes_sheet.dart';

/// Cor do selo de cada motivo, só com cores do design system.
Color corDoMotivo(MotivoVisita m) => switch (m) {
  MotivoVisita.cobrancaEmAtraso => AppColors.statusInadimplente,
  MotivoVisita.venceNaData => AppColors.statusAtencao,
  MotivoVisita.reativacao => AppColors.primary,
  MotivoVisita.clienteNovo => AppColors.textSecondary,
  MotivoVisita.bloqueadoCobrar => AppColors.statusBloqueado,
};

/// Selo do motivo principal da recomendação.
class SeloMotivoVisita extends StatelessWidget {
  const SeloMotivoVisita(this.motivo, {super.key});

  final MotivoVisita motivo;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(motivo.rotulo, corDoMotivo(motivo));
}

/// Bloco "Recomendados para visitar" (KAN-48), que preenche o slot
/// `recomendados` da agenda (KAN-47): os N melhores clientes da rota e da
/// data escolhidas, em uma lista horizontal compacta.
class RecomendadosParaVisitar extends ConsumerWidget {
  const RecomendadosParaVisitar({super.key});

  static const double _alturaLista = 168;
  static const double _larguraItem = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recomendacoes = ref.watch(recomendacoesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recomendados para visitar',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                if ((recomendacoes.value?.todas.length ?? 0) > 0)
                  TextButton(
                    onPressed: () => mostrarRecomendacoes(context),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            recomendacoes.when(
              data: (dados) => _conteudo(context, ref, dados),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox.square(
                    dimension: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, _) {
                debugPrint('Erro ao carregar as recomendações: $error');
                return const EmptyState(
                  compacto: true,
                  icone: Icons.error_outline,
                  titulo: 'Erro ao carregar as recomendações',
                  descricao: 'Verifique a conexão e tente novamente.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(
    BuildContext context,
    WidgetRef ref,
    RecomendacoesDoDia dados,
  ) {
    final filhos = <Widget>[];

    if (dados.melhores.isEmpty) {
      filhos.add(
        const EmptyState(
          compacto: true,
          icone: Icons.check_circle_outline,
          titulo: 'Nenhum cliente para visitar agora',
          descricao:
              'Ninguém com cobrança pendente ou sem comprar há muito '
              'tempo.',
        ),
      );
    } else {
      filhos.add(
        SizedBox(
          height: _alturaLista,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dados.melhores.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => SizedBox(
              width: _larguraItem,
              child: _ItemRecomendado(
                recomendacao: dados.melhores[i],
                data: dados.data,
              ),
            ),
          ),
        ),
      );
    }

    if (dados.dispensados > 0) {
      filhos.add(
        Row(
          children: [
            Expanded(
              child: Text(
                dados.dispensados == 1
                    ? '1 cliente dispensado hoje'
                    : '${dados.dispensados} clientes dispensados hoje',
                style: AppTextStyles.caption,
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(dispensadosHojeProvider.notifier)
                  .restaurar(dados.data),
              child: const Text('Desfazer'),
            ),
          ],
        ),
      );
    }
    if (!dados.parcelasDisponiveis) {
      filhos.add(
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Estimado pelo resumo do cliente: as parcelas ainda estão '
            'carregando.',
            style: AppTextStyles.caption,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filhos,
    );
  }
}

class _ItemRecomendado extends ConsumerWidget {
  const _ItemRecomendado({required this.recomendacao, required this.data});

  final Recomendacao recomendacao;
  final DateTime data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = recomendacao.item.cliente;

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.background,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () =>
            Navigator.of(context)
                .pushNamed(AppRoutes.detalheCliente, arguments: c.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.nome,
                style: AppTextStyles.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: SeloMotivoVisita(recomendacao.motivo),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                recomendacao.textoMotivo,
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Flexible: em telas estreitas (ou fonte grande) o texto
                  // encurta em vez de estourar o cartão.
                  Flexible(
                    child: TextButton(
                      onPressed: () => ref
                          .read(dispensadosHojeProvider.notifier)
                          .dispensar(c.id, data),
                      child: const Text(
                        'Dispensar hoje',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nova venda',
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(AppRoutes.novaVenda, arguments: c.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
