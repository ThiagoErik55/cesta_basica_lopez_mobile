import 'package:flutter/material.dart';

import '../../features/produto/data/produto_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Card de produto usado na tela de estoque.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.produto, this.onTap, super.key});

  final ProdutoModel produto;
  final VoidCallback? onTap;

  static const double _imagemLado = 48;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const _ImagemPlaceholder(lado: _imagemLado),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(produto.nome, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${produto.marca} · ${produto.codigo}',
                      style: AppTextStyles.cardSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Estoque: ${produto.estoqueAtual}',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              if (produto.estoqueBaixo) ...[
                const SizedBox(width: AppSpacing.sm),
                const _BadgeEstoqueBaixo(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Espaço reservado para a imagem do produto — o projeto ainda não tem
/// fotos de produto (sem Firebase Storage, ver ADR 001).
class _ImagemPlaceholder extends StatelessWidget {
  const _ImagemPlaceholder({required this.lado});

  final double lado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
    );
  }
}

class _BadgeEstoqueBaixo extends StatelessWidget {
  const _BadgeEstoqueBaixo();

  @override
  Widget build(BuildContext context) {
    final cor = AppColors.corDoEstoque(true);
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
        'ESTOQUE BAIXO',
        style: AppTextStyles.badge.copyWith(color: corTexto),
      ),
    );
  }
}
