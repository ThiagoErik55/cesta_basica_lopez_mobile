import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/periodo.dart';
import '../domain/relatorio_linha.dart';
import 'painel_detalhes.dart';

/// Abre o detalhe de uma linha de atendimento (KAN-53): vendas por dia,
/// produtos mais vendidos e clientes que mais compraram na semana.
/// Mostra só o nome do cliente, nunca o CPF.
Future<void> mostrarDetalheLinha(
  BuildContext context, {
  required LinhaRelatorio linha,
  required Periodo semana,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DetalheLinhaSheet(linha: linha, semana: semana),
);

class DetalheLinhaSheet extends StatelessWidget {
  const DetalheLinhaSheet({
    required this.linha,
    required this.semana,
    super.key,
  });

  final LinhaRelatorio linha;
  final Periodo semana;

  @override
  Widget build(BuildContext context) {
    final detalhe = detalharLinha(linha, semana);
    final diasComVenda = [
      for (final p in detalhe.vendasPorDia)
        if (p.totais.vendas > 0) p,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controle) => ListView(
        controller: controle,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Text(linha.rotulo, style: AppTextStyles.cardTitle),
          Text(
            '${formatarData(semana.inicio)} a ${formatarData(semana.ultimoDia)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(titulo: 'Vendas por dia'),
          const SizedBox(height: AppSpacing.sm),
          if (diasComVenda.isEmpty)
            const Text(
              'Nenhuma venda nesta linha na semana.',
              style: AppTextStyles.caption,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (i, p) in diasComVenda.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      title: Text(
                        formatarData(p.dia),
                        style: AppTextStyles.cardTitle,
                      ),
                      subtitle: Text(
                        p.totais.vendas == 1
                            ? '1 venda'
                            : '${p.totais.vendas} vendas',
                        style: AppTextStyles.cardSubtitle,
                      ),
                      trailing: Text(
                        formatarCentavos(p.totais.faturamento),
                        style: AppTextStyles.money,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Mais vendidos'),
          const SizedBox(height: AppSpacing.sm),
          TopProdutos(produtos: detalhe.topProdutos),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Clientes que mais compraram'),
          const SizedBox(height: AppSpacing.sm),
          if (detalhe.topClientes.isEmpty)
            const Text(
              'Nenhuma venda no período.',
              style: AppTextStyles.caption,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (i, c) in detalhe.topClientes.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      leading: Text(
                        '${i + 1}º',
                        style: AppTextStyles.cardTitle,
                      ),
                      title: Text(c.nome, style: AppTextStyles.cardTitle),
                      subtitle: Text(
                        c.vendas == 1 ? '1 venda' : '${c.vendas} vendas',
                        style: AppTextStyles.cardSubtitle,
                      ),
                      trailing: Text(
                        formatarCentavos(c.valor),
                        style: AppTextStyles.money,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
