import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conectividade_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Badge de conectividade. Lê o [conectividadeProvider] já existente —
/// não cria um provider novo.
class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectado = ref.watch(conectividadeProvider).value ?? false;
    final cor = conectado ? AppColors.online : AppColors.offline;
    final corTexto = AppColors.textoContrastante(cor);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        conectado ? 'ONLINE' : 'OFFLINE',
        style: AppTextStyles.badge.copyWith(color: corTexto),
      ),
    );
  }
}
