import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/controle_estoque.dart';

/// Faixa da aba Produtos com a contagem de produtos em alerta de estoque
/// (KAN-44) e a ação "Ver", que abre a tela Estoque filtrada em alertas.
/// Sem alertas, não ocupa espaço.
class FaixaAlertaEstoque extends StatelessWidget {
  const FaixaAlertaEstoque({
    required this.alertas,
    required this.onVer,
    super.key,
  });

  final int alertas;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    final texto = textoFaixaAlertas(alertas);
    if (texto == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Material(
        color: AppColors.statusAtencao.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.statusAtencao,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(texto, style: AppTextStyles.body)),
              TextButton(onPressed: onVer, child: const Text('Ver')),
            ],
          ),
        ),
      ),
    );
  }
}
