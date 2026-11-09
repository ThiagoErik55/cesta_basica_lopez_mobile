import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/logout_button.dart';

/// Aba financeira (RF27, RF29). Dá acesso ao controle de promissórias
/// (KAN-34); a apuração de lucro e o lançamento de despesas chegam em
/// uma próxima sprint.
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
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Promissórias', style: AppTextStyles.cardTitle),
              subtitle: const Text(
                'Vendas parceladas, saldos e vencimentos',
                style: AppTextStyles.cardSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.promissorias),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const EmptyState(
            icone: Icons.attach_money,
            titulo: 'Apuração em construção',
            descricao:
                'A apuração de lucro e o lançamento de despesas '
                'chegam em uma próxima sprint.',
          ),
        ],
      ),
    );
  }
}
