import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/agregacao_financeira.dart';

/// Despesas do período, dia a dia (KAN-52).
class DespesasPorDia extends StatelessWidget {
  const DespesasPorDia({required this.dias, super.key});

  final List<PontoDia> dias;

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) {
      return const _SemDados('Nenhuma despesa no período.');
    }
    return Card(
      child: Column(
        children: [
          for (final (i, p) in dias.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            ListTile(
              title: Text(formatarData(p.dia), style: AppTextStyles.cardTitle),
              subtitle: Text(
                p.totais.quantidadeDespesas == 1
                    ? '1 lançamento'
                    : '${p.totais.quantidadeDespesas} lançamentos',
                style: AppTextStyles.cardSubtitle,
              ),
              trailing: Text(
                formatarMoeda(p.totais.despesas / 100),
                style: AppTextStyles.money.copyWith(
                  color: AppColors.statusInadimplente,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top 5 produtos mais vendidos do período (KAN-52).
class TopProdutos extends StatelessWidget {
  const TopProdutos({required this.produtos, super.key});

  final List<ProdutoVendido> produtos;

  @override
  Widget build(BuildContext context) {
    if (produtos.isEmpty) {
      return const _SemDados('Nenhuma venda no período.');
    }
    return Card(
      child: Column(
        children: [
          for (final (i, p) in produtos.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: Text('${i + 1}º', style: AppTextStyles.cardTitle),
              title: Text(p.nome, style: AppTextStyles.cardTitle),
              subtitle: Text(
                p.quantidade == 1 ? '1 unidade' : '${p.quantidade} unidades',
                style: AppTextStyles.cardSubtitle,
              ),
              trailing: Text(
                formatarMoeda(p.faturamento / 100),
                style: AppTextStyles.money,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SemDados extends StatelessWidget {
  const _SemDados(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(texto, style: AppTextStyles.caption),
  );
}
