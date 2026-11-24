import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/logout_button.dart';
import 'saldo_dia_secao.dart';
import 'seletor_dia.dart';

/// Aba financeira (RF27, RF29): saldo do dia do vendedor (KAN-51) e
/// acesso às despesas (KAN-50) e ao controle de promissórias (KAN-34).
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
          const SeletorDia(),
          const SizedBox(height: AppSpacing.sm),
          const SaldoDiaSecao(),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Controles'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text(
                'Painel financeiro',
                style: AppTextStyles.cardTitle,
              ),
              subtitle: const Text(
                'Lucro, despesas e vendas por semana, mês ou período',
                style: AppTextStyles.cardSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.painelFinanceiro),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_gas_station_outlined),
              title: const Text('Despesas', style: AppTextStyles.cardTitle),
              subtitle: const Text(
                'Combustível, alimentação e outros gastos do dia',
                style: AppTextStyles.cardSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.despesas),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        ],
      ),
    );
  }
}
