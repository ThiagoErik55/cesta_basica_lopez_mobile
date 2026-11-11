import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/controle_estoque.dart';

/// Selo colorido da situação do estoque. Saldo negativo aparece como
/// "Negativo", em destaque.
class SeloSituacaoEstoque extends StatelessWidget {
  const SeloSituacaoEstoque(this.item, {super.key});

  final ItemEstoque item;

  @override
  Widget build(BuildContext context) {
    if (item.negativo) {
      return const StatusBadge('Negativo', AppColors.statusBloqueado);
    }
    return switch (item.situacao) {
      SituacaoEstoque.normal => const StatusBadge(
        'Normal',
        AppColors.statusEmDia,
      ),
      SituacaoEstoque.baixo => const StatusBadge(
        'Estoque baixo',
        AppColors.statusAtencao,
      ),
      SituacaoEstoque.semEstoque => const StatusBadge(
        'Sem estoque',
        AppColors.statusInadimplente,
      ),
    };
  }
}
