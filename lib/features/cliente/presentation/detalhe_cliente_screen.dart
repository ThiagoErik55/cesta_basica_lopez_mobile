import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import 'cliente_providers.dart';

/// Detalhes do cliente. Placeholder — o conteúdo (dados, histórico de
/// compras e pagamentos, score) chega no card de Detalhes do Cliente.
/// Recebe o id do cliente como argumento da rota.
class DetalheClienteScreen extends ConsumerWidget {
  const DetalheClienteScreen({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(clientePorIdProvider(clienteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(cliente.value?.nome ?? 'Cliente'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: const Center(
        child: EmptyState(
          icone: Icons.person_outline,
          titulo: 'Detalhes em construção',
          descricao:
              'Dados, histórico de compras e pagamentos do cliente '
              'chegam em um próximo card.',
        ),
      ),
    );
  }
}
