import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/logout_button.dart';

/// Aba financeira (RF27, RF29). Placeholder do KAN-10 — a apuração de
/// lucro e o lançamento de despesas chegam em uma próxima sprint.
class FinanceiroScreen extends StatelessWidget {
  const FinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
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
          icone: Icons.attach_money,
          titulo: 'Financeiro em construção',
          descricao:
              'A apuração de lucro e o lançamento de despesas '
              'chegam em uma próxima sprint.',
        ),
      ),
    );
  }
}
