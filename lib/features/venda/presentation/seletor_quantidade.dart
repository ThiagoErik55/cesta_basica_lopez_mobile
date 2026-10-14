import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Botões − e + com a quantidade no meio, usados na lista de produtos e
/// no carrinho da nova venda (KAN-25).
class SeletorQuantidade extends StatelessWidget {
  const SeletorQuantidade({
    required this.quantidade,
    required this.onAdicionar,
    required this.onRemover,
    super.key,
  });

  final int quantidade;
  final VoidCallback onAdicionar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
            onPressed: quantidade > 0 ? onRemover : null,
          ),
          SizedBox(
            width: AppSpacing.lg,
            child: Text(
              '$quantidade',
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Aumentar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
            onPressed: onAdicionar,
          ),
        ],
      ),
    );
  }
}
