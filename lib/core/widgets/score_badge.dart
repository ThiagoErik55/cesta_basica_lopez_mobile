import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Badge circular com a letra do score do cliente (RF05).
class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.score, {super.key});

  final ScoreCliente score;

  static const double _diametro = 28;

  @override
  Widget build(BuildContext context) {
    final cor = AppColors.corDoScore(score);
    final corTexto = AppColors.textoContrastante(cor);
    return Container(
      width: _diametro,
      height: _diametro,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      child: Text(
        score.name.toUpperCase(),
        style: AppTextStyles.badge.copyWith(color: corTexto),
      ),
    );
  }
}
