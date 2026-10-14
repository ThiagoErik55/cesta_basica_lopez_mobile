import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/primary_button.dart';
import 'carrinho_sheet.dart';

/// Rodapé fixo da nova venda: total, carrinho (KAN-25) e, quando
/// [onFinalizar] é informado, o botão de finalizar (KAN-27).
class RodapeVenda extends StatelessWidget {
  const RodapeVenda({
    required this.total,
    required this.unidades,
    this.descricaoPagamento,
    this.finalizando = false,
    this.onFinalizar,
    super.key,
  });

  final double total;
  final int unidades;

  /// Ex. "Pix" ou "Parcelado em 3x". `null` enquanto não escolhido.
  final String? descricaoPagamento;
  final bool finalizando;
  final VoidCallback? onFinalizar;

  @override
  Widget build(BuildContext context) {
    final pagamento = descricaoPagamento;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total da venda ($unidades itens)'
                          '${pagamento == null ? '' : ' · $pagamento'}',
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          formatarMoeda(total),
                          style: AppTextStyles.moneyLarge.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.xl + AppSpacing.sm),
                    ),
                    onPressed: () => mostrarCarrinho(context),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Carrinho'),
                  ),
                ],
              ),
              if (onFinalizar != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  texto: 'Finalizar venda',
                  carregando: finalizando,
                  onPressed: onFinalizar,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
