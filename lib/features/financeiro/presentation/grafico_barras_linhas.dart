import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/relatorio_linha.dart';

/// Barras por linha de atendimento (KAN-53): faturamento e lucro bruto
/// lado a lado. Desenhado com [CustomPainter], sem pacote novo.
class GraficoBarrasLinhas extends StatelessWidget {
  const GraficoBarrasLinhas({required this.linhas, super.key});

  final List<LinhaRelatorio> linhas;

  static const _faturamento = AppColors.primary;
  static const _lucro = AppColors.scoreA;

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Wrap(
              spacing: AppSpacing.md,
              children: [
                _Legenda(cor: _faturamento, texto: 'Faturamento'),
                _Legenda(cor: _lucro, texto: 'Lucro bruto'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label:
                  'Gráfico de barras de faturamento e lucro bruto por '
                  'linha de atendimento',
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _PintorBarras(linhas),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final l in linhas)
                  Expanded(
                    child: Text(
                      l.rotulo,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
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

class _PintorBarras extends CustomPainter {
  _PintorBarras(this.linhas);

  final List<LinhaRelatorio> linhas;

  @override
  void paint(Canvas canvas, Size size) {
    var maximo = 0;
    var minimo = 0;
    for (final l in linhas) {
      for (final v in [l.totais.faturamento, l.totais.lucroBruto]) {
        if (v > maximo) maximo = v;
        if (v < minimo) minimo = v;
      }
    }
    final faixa = (maximo - minimo) == 0 ? 1 : (maximo - minimo);
    double y(int v) => size.height - (v - minimo) / faixa * size.height;

    final eixo = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), eixo);

    final largura = size.width / linhas.length;
    final barra = largura * 0.28;
    for (final (i, l) in linhas.indexed) {
      final centro = largura * i + largura / 2;
      void desenhar(int valor, double dx, Color cor) {
        final topo = y(valor);
        final base = y(0);
        canvas.drawRect(
          Rect.fromLTRB(
            centro + dx,
            topo < base ? topo : base,
            centro + dx + barra,
            topo < base ? base : topo,
          ),
          Paint()..color = cor,
        );
      }

      desenhar(
        l.totais.faturamento,
        -barra - 2,
        GraficoBarrasLinhas._faturamento,
      );
      desenhar(l.totais.lucroBruto, 2, GraficoBarrasLinhas._lucro);
    }
  }

  @override
  bool shouldRepaint(_PintorBarras antigo) => antigo.linhas != linhas;
}
