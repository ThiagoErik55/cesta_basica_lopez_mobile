import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import 'nova_venda_providers.dart';
import 'rodape_venda.dart';
import 'secao_produtos_venda.dart';

/// Nova venda (RF10), aberta pelo botão central da navegação.
///
/// - KAN-25: listagem de produtos e carrinho
class NovaVendaScreen extends ConsumerWidget {
  const NovaVendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        children: const [SecaoProdutosVenda()],
      ),
      bottomNavigationBar: RodapeVenda(
        total: venda.total,
        unidades: venda.unidades,
      ),
    );
  }
}
