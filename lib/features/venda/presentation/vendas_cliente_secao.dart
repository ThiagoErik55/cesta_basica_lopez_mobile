import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/rotulos_venda.dart';
import 'pos_venda_providers.dart';

/// Vendas reais do cliente, na tela de detalhes do cliente. Cada venda
/// abre os detalhes, onde ficam troca (KAN-28) e observações (KAN-29).
class VendasClienteSecao extends ConsumerWidget {
  const VendasClienteSecao({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendas = ref.watch(vendasDoClienteProvider(clienteId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          titulo: 'Vendas',
          acao: TextButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.novaVenda, arguments: clienteId),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Nova venda'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: vendas.when(
              data: (lista) => lista.isEmpty
                  ? const Text(
                      'Nenhuma venda registrada.',
                      style: AppTextStyles.body,
                    )
                  : Column(
                      children: [
                        for (final (i, venda) in lista.indexed) ...[
                          if (i > 0) const Divider(color: AppColors.border),
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.detalheVenda,
                              arguments: venda.id,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nota ${venda.numeroNota}',
                                          style: AppTextStyles.cardTitle,
                                        ),
                                        Text(
                                          '${formatarData(venda.data)} · '
                                          '${venda.tipo.rotulo}'
                                          '${venda.trocas.isEmpty ? '' : ' · com troca'}',
                                          style: AppTextStyles.cardSubtitle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatarMoeda(venda.valorTotal),
                                    style: AppTextStyles.money,
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                // Erro comum aqui: índice composto ausente no Firestore
                // (ver firestore.indexes.json).
                debugPrint('Erro ao carregar vendas do cliente: $error');
                return const Text(
                  'Erro ao carregar vendas.',
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
