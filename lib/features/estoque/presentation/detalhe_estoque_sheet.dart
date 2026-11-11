import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../venda/presentation/pos_venda_providers.dart';
import '../data/movimento_estoque_model.dart';
import '../domain/controle_estoque.dart';
import 'estoque_providers.dart';
import 'selo_situacao_estoque.dart';

/// Abre o detalhe do produto no estoque: dados e histórico de
/// movimentações.
///
/// [aoRegistrarEntrada] é o ponto de extensão da KAN-42: enquanto for
/// `null`, o botão "Registrar entrada" aparece desabilitado. A KAN-42 só
/// precisa passar a ação aqui.
Future<void> mostrarDetalheEstoque(
  BuildContext context,
  ItemEstoque item, {
  VoidCallback? aoRegistrarEntrada,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      DetalheEstoqueSheet(item: item, aoRegistrarEntrada: aoRegistrarEntrada),
);

class DetalheEstoqueSheet extends ConsumerWidget {
  const DetalheEstoqueSheet({
    required this.item,
    this.aoRegistrarEntrada,
    super.key,
  });

  final ItemEstoque item;
  final VoidCallback? aoRegistrarEntrada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = item.produto;
    final movimentos = ref.watch(movimentosDoProdutoProvider(p.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controle) => ListView(
        controller: controle,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(child: Text(p.nome, style: AppTextStyles.screenTitle)),
              const SizedBox(width: AppSpacing.sm),
              SeloSituacaoEstoque(item),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${p.marca} · ${p.codigo} · '
            '${p.categoria.isEmpty ? 'Sem categoria' : p.categoria}',
            style: AppTextStyles.cardSubtitle,
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _Linha(
                    'Estoque atual',
                    '${p.estoqueAtual}',
                    destaque: item.negativo,
                  ),
                  _Linha('Estoque mínimo', '${p.estoqueMinimo}'),
                  _Linha('Preço', formatarMoeda(p.preco)),
                  _Linha('Custo atual', formatarMoeda(p.custoAtual)),
                  _Linha(
                    'Valor em estoque',
                    formatarMoeda(item.valorEmEstoque),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // KAN-42 liga este botão passando [aoRegistrarEntrada].
          OutlinedButton.icon(
            onPressed: aoRegistrarEntrada,
            icon: const Icon(Icons.add),
            label: Text(
              aoRegistrarEntrada == null
                  ? 'Registrar entrada (em breve)'
                  : 'Registrar entrada',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Movimentações'),
          const SizedBox(height: AppSpacing.sm),
          movimentos.when(
            data: (lista) => lista.isEmpty
                ? const EmptyState(
                    icone: Icons.swap_vert,
                    titulo: 'Nenhuma movimentação',
                    descricao: 'As entradas e saídas do produto aparecem aqui.',
                  )
                : Column(
                    children: [
                      for (final m in lista) _LinhaMovimento(movimento: m),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) {
              debugPrint('Erro ao carregar movimentações: $error');
              return const EmptyState(
                icone: Icons.error_outline,
                titulo: 'Erro ao carregar movimentações',
                descricao: 'Verifique a conexão e abra o produto novamente.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor, {this.destaque = false});

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(rotulo, style: AppTextStyles.body)),
        Text(
          valor,
          style: AppTextStyles.money.copyWith(
            color: destaque ? AppColors.scoreD : null,
          ),
        ),
      ],
    ),
  );
}

class _LinhaMovimento extends ConsumerWidget {
  const _LinhaMovimento({required this.movimento});

  final MovimentoEstoqueModel movimento;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = movimento;
    final entrada = m.tipo == TipoMovimento.entrada;
    final cor = entrada ? AppColors.scoreA : AppColors.scoreD;

    final vendaId = m.vendaId;
    final nota = vendaId == null
        ? null
        : ref
              .watch(vendaPorIdProvider(vendaId))
              .maybeWhen(data: (v) => v?.numeroNota, orElse: () => null);
    final origem = switch (m.tipo) {
      TipoMovimento.entrada => 'Lançamento de estoque',
      TipoMovimento.saida ||
      TipoMovimento.troca => nota == null ? 'Venda' : 'Venda · Nota $nota',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(entrada ? Icons.south_west : Icons.north_east, color: cor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.tipo.rotulo, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$origem · ${formatarDataHora(m.data)}'
                  '${m.custoUnitario == null ? '' : ' · custo ${formatarMoeda(m.custoUnitario!)}'}',
                  style: AppTextStyles.cardSubtitle,
                ),
              ],
            ),
          ),
          Text(
            '${entrada ? '+' : '-'}${m.quantidade}',
            style: AppTextStyles.money.copyWith(color: cor),
          ),
        ],
      ),
    );
  }
}
