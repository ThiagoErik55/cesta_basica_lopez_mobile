import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/agregacao_financeira.dart';
import '../domain/relatorio_linha.dart';
import 'painel_indicadores.dart';

String _percentual(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

/// Tabela do relatório por linha de atendimento (KAN-53): uma linha por
/// linha de atendimento, por faturamento, e o TOTAL no fim. Rola na
/// horizontal no celular. Tocar numa linha abre o detalhe dela
/// ([aoAbrirLinha]); o total não abre nada.
class RelatorioTabela extends StatelessWidget {
  const RelatorioTabela({
    required this.relatorio,
    required this.aoAbrirLinha,
    super.key,
  });

  final RelatorioSemanal relatorio;
  final void Function(LinhaRelatorio linha) aoAbrirLinha;

  @override
  Widget build(BuildContext context) {
    final recebidoCompleto = relatorio.recebidoCompleto;
    String recebido(TotaisFinanceiros t) =>
        recebidoCompleto ? formatarCentavos(t.recebido) : '—';

    DataCell texto(String valor, {bool negrito = false}) => DataCell(
      Text(
        valor,
        style: negrito
            ? AppTextStyles.cardTitle
            : AppTextStyles.cardSubtitle.copyWith(color: AppColors.textPrimary),
      ),
    );
    DataCell variacao(double? v) =>
        DataCell(VariacaoPercentual(variacao: v, compacto: true));

    DataColumn coluna(String rotulo, {bool numerica = true}) => DataColumn(
      label: Text(rotulo, style: AppTextStyles.badge),
      numeric: numerica,
    );

    final total = relatorio.total;
    final margemTotal = total.faturamento <= 0
        ? 0.0
        : total.lucroBruto / total.faturamento * 100;

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 16,
          columns: [
            coluna('Linha', numerica: false),
            coluna('Vendas'),
            coluna('Faturamento'),
            coluna('Custo'),
            coluna('Lucro bruto'),
            coluna('Margem'),
            coluna('Ticket médio'),
            coluna('Recebido'),
            coluna('Particip.'),
            coluna('Fat. vs. ant.'),
            coluna('Lucro vs. ant.'),
          ],
          rows: [
            for (final l in relatorio.linhas)
              DataRow(
                onSelectChanged: (_) => aoAbrirLinha(l),
                cells: [
                  texto(l.rotulo, negrito: true),
                  texto('${l.totais.vendas}'),
                  texto(formatarCentavos(l.totais.faturamento)),
                  texto(formatarCentavos(l.totais.custo)),
                  texto(formatarCentavos(l.totais.lucroBruto)),
                  texto(_percentual(l.margem)),
                  texto(formatarCentavos(l.totais.ticketMedio)),
                  texto(recebido(l.totais)),
                  texto(_percentual(l.participacao)),
                  variacao(l.variacaoFaturamento),
                  variacao(l.variacaoLucroBruto),
                ],
              ),
            DataRow(
              color: WidgetStatePropertyAll(
                AppColors.primary.withValues(alpha: 0.08),
              ),
              cells: [
                texto('TOTAL', negrito: true),
                texto('${total.vendas}', negrito: true),
                texto(formatarCentavos(total.faturamento), negrito: true),
                texto(formatarCentavos(total.custo), negrito: true),
                texto(formatarCentavos(total.lucroBruto), negrito: true),
                texto(_percentual(margemTotal), negrito: true),
                texto(formatarCentavos(total.ticketMedio), negrito: true),
                texto(recebido(total), negrito: true),
                texto(relatorio.vazio ? '0,0%' : '100,0%', negrito: true),
                variacao(relatorio.variacaoFaturamento),
                variacao(relatorio.variacaoLucroBruto),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
