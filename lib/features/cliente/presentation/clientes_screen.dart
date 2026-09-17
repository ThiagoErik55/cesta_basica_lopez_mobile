import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';

/// Aba de cadastro e busca de clientes (RF01, RF02). Placeholder do
/// KAN-10 — o cadastro e a busca chegam em uma próxima sprint.
class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: const Center(
        child: EmptyState(
          icone: Icons.people_outline,
          titulo: 'Clientes em construção',
          descricao:
              'O cadastro e a busca de clientes chegam em uma '
              'próxima sprint.',
        ),
      ),
    );
  }
}
