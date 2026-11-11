import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/estoque_venda.dart';
import 'nova_venda_providers.dart';
import 'seletor_quantidade.dart';

/// Revisão do carrinho da nova venda (KAN-25): itens, quantidades e
/// total. As alterações valem direto no estado da venda.
Future<void> mostrarCarrinho(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const _CarrinhoSheet(),
);

class _CarrinhoSheet extends ConsumerWidget {
  const _CarrinhoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venda = ref.watch(novaVendaProvider);
    final notifier = ref.read(novaVendaProvider.notifier);
    final itens = venda.itens.values.toList();
    final acima = {for (final i in itensAcimaDoEstoque(itens)) i.produtoId: i};

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Carrinho', style: AppTextStyles.sectionTitle),
                ),
                if (itens.isNotEmpty)
                  TextButton(
                    onPressed: notifier.limparCarrinho,
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (itens.isEmpty)
              const EmptyState(
                icone: Icons.shopping_cart_outlined,
                titulo: 'Carrinho vazio',
                descricao: 'Adicione produtos na tela da venda.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itens.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.border),
                  itemBuilder: (context, i) {
                    final item = itens[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.produto.nome,
                                style: AppTextStyles.cardTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${formatarMoeda(item.produto.preco)} cada · '
                                '${formatarMoeda(item.subtotal)}',
                                style: AppTextStyles.cardSubtitle,
                              ),
                              if (acima[item.produto.id] case final falta?)
                                Text(
                                  textoFaltaEstoque(falta),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.statusInadimplente,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SeletorQuantidade(
                          quantidade: item.quantidade,
                          onAdicionar: () => notifier.adicionar(item.produto),
                          onRemover: () => notifier.remover(item.produto),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total (${venda.unidades} itens)',
                    style: AppTextStyles.body,
                  ),
                ),
                Text(formatarMoeda(venda.total), style: AppTextStyles.money),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
