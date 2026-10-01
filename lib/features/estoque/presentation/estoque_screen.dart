import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/logout_button.dart';

/// Aba de estoque (RF22, RF23, RF24, RF25). Placeholder do KAN-10 — a
/// listagem de produtos e movimentos chega em uma próxima sprint.
class EstoqueScreen extends StatelessWidget {
  const EstoqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        actions: const [
          LogoutButton(),
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: const Center(
        child: EmptyState(
          icone: Icons.inventory_2_outlined,
          titulo: 'Estoque em construção',
          descricao:
              'A listagem de produtos e movimentos chega em uma '
              'próxima sprint.',
        ),
      ),
    );
  }
}
