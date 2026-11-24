import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/agregacao_financeira.dart';

/// Evolução diária do período (KAN-52): faturamento, despesas e lucro
/// líquido, em linhas. Desenhado com [CustomPainter], sem pacote. Sem
/// rótulo por dia: só início, meio e fim, para 30 dias caberem no celular.
class GraficoEvolucao extends StatelessWidget {
  const GraficoEvolucao({required this.serie, super.key});

  final List<PontoDia> serie;

  static const _faturamento = AppColors.primary;
  static const _despesas = AppColors.statusInadimplente;
  static const _lucro = AppColors.scoreA;

  static String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (serie.isEmpty) return const SizedBox.shrink();
    final meio = serie[(serie.length - 1) ~/ 2].dia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Legenda(cor: _faturamento, texto: 'Faturamento'),
                _Legenda(cor: _despesas, texto: 'Despesas'),
                _Legenda(cor: _lucro, texto: 'Lucro líquido'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label:
                  'Gráfico de evolução diária de faturamento, despesas e '
                  'lucro líquido, de ${_dia(serie.first.dia)} a '
                  '${_dia(serie.last.dia)}',
              child: SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: _PintorEvolucao(serie),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_dia(serie.first.dia), style: AppTextStyles.caption),
                if (serie.length > 2)
                  Text(_dia(meio), style: AppTextStyles.caption),
                if (serie.length > 1)
                  Text(_dia(serie.last.dia), style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(texto, style: AppTextStyles.caption),
    ],
  );
}

class _PintorEvolucao extends CustomPainter {
  _PintorEvolucao(this.serie);

  final List<PontoDia> serie;

  @override
  void paint(Canvas canvas, Size size) {
    final series = <(Color, int Function(TotaisFinanceiros))>[
      (GraficoEvolucao._faturamento, (t) => t.faturamento),
      (GraficoEvolucao._despesas, (t) => t.despesas),
      (GraficoEvolucao._lucro, (t) => t.lucroLiquido),
    ];

    var maximo = 0;
    var minimo = 0;
    for (final p in serie) {
      for (final (_, valor) in series) {
        final v = valor(p.totais);
        if (v > maximo) maximo = v;
        if (v < minimo) minimo = v;
      }
    }
    final faixa = (maximo - minimo) == 0 ? 1 : (maximo - minimo);

    double y(int v) => size.height - (v - minimo) / faixa * size.height;
    double x(int i) => serie.length == 1
        ? size.width / 2
        : i / (serie.length - 1) * size.width;

    final eixo = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), eixo);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), eixo);

    for (final (cor, valor) in series) {
      final linha = Paint()
        ..color = cor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final ponto = Paint()..color = cor;
      final caminho = Path();
      for (var i = 0; i < serie.length; i++) {
        final o = Offset(x(i), y(valor(serie[i].totais)));
        i == 0 ? caminho.moveTo(o.dx, o.dy) : caminho.lineTo(o.dx, o.dy);
      }
      if (serie.length > 1) canvas.drawPath(caminho, linha);
      // Poucos dias: marca cada ponto. Muitos: só a linha, para não poluir.
      if (serie.length <= 14) {
        for (var i = 0; i < serie.length; i++) {
          canvas.drawCircle(Offset(x(i), y(valor(serie[i].totais))), 3, ponto);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PintorEvolucao antigo) => antigo.serie != serie;
}
