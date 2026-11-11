import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/logout_button.dart';

/// Aba de agenda do vendedor (RF08, RF09). Placeholder do KAN-10 — a
/// lista de clientes a visitar chega em uma próxima sprint.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          // Cadastro de rotas (KAN-45): as rotas organizam a agenda.
          IconButton(
            tooltip: 'Rotas',
            icon: const Icon(Icons.route_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.rotas),
          ),
          const LogoutButton(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: const Center(
        child: EmptyState(
          icone: Icons.calendar_today_outlined,
          titulo: 'Agenda em construção',
          descricao:
              'A lista de clientes a visitar no dia chega em uma '
              'próxima sprint.',
        ),
      ),
    );
  }
}
