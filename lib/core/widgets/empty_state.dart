import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Estado vazio padrão de listas — aparece em qualquer tela enquanto não
/// houver dados.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.acao,
    super.key,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final Widget? acao;

  static const double _tamanhoIcone = AppSpacing.xl * 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: _tamanhoIcone, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            titulo,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            descricao,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (acao != null) ...[const SizedBox(height: AppSpacing.lg), acao!],
        ],
      ),
    );
  }
}
