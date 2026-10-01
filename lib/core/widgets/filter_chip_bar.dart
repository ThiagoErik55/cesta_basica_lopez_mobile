import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Opção de um [FilterChipBar]: o rótulo exibido e o valor que ela
/// representa. Valor `null` é a opção "sem filtro" (ex. "Todos").
class OpcaoFiltro<T> {
  const OpcaoFiltro(this.rotulo, this.valor);

  final String rotulo;
  final T? valor;
}

/// Linha de chips de escolha única, rolável na horizontal, para filtrar
/// listas (KAN-16). Exatamente uma opção fica selecionada por vez.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    required this.opcoes,
    required this.selecionado,
    required this.onSelecionar,
    super.key,
  });

  final List<OpcaoFiltro<T>> opcoes;
  final T? selecionado;
  final ValueChanged<T?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final corTextoSelecionado = AppColors.textoContrastante(AppColors.primary);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final opcao in opcoes) ...[
            ChoiceChip(
              label: Text(opcao.rotulo),
              selected: opcao.valor == selecionado,
              onSelected: (_) => onSelecionar(opcao.valor),
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              labelStyle: AppTextStyles.body.copyWith(
                color: opcao.valor == selecionado
                    ? corTextoSelecionado
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
