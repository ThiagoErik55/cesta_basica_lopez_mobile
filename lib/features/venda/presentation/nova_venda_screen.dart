import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';

/// Fluxo de nova venda (RF10, RF12, RF18, RF19), aberto pelo botão
/// central da navegação principal. Placeholder do KAN-10 — o
/// preenchimento do pedido chega em uma próxima sprint.
///
/// Tem AppBar com botão de voltar (padrão do Flutter para uma rota
/// empilhada) porque é um fluxo com começo e fim, não uma aba.
class NovaVendaScreen extends StatelessWidget {
  const NovaVendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const Center(
        child: EmptyState(
          icone: Icons.shopping_cart_outlined,
          titulo: 'Nova venda em construção',
          descricao: 'O registro de pedidos chega em uma próxima sprint.',
        ),
      ),
    );
  }
}
