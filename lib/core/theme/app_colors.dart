import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/enums.dart';

/// Paleta central do design system (KAN-12). Nenhuma cor pode ser
/// declarada fora deste arquivo — toda tela ou componente referencia
/// estas constantes.
///
/// Os valores abaixo são as aproximações fornecidas no card KAN-12,
/// extraídas visualmente do protótipo da Sprint 1. Nenhum arquivo de
/// Figma está versionado no repositório no momento desta implementação
/// (não há docs/prototipo nem PDF do Figma) — os valores devem ser
/// confirmados contra o arquivo original assim que ele for
/// disponibilizado.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFFF97316);
  static const Color primaryDark = Color(0xFF8B4A22);
  static const Color background = Color(0xFFFDFBF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F1D1A);
  static const Color textSecondary = Color(0xFF6B6862);
  static const Color border = Color(0xFFE8E4DB);

  // Score do cliente (RF05, ScoreCliente em core/domain/enums.dart).
  static const Color scoreA = Color(0xFF16A34A);
  static const Color scoreB = Color(0xFFF59E0B);
  static const Color scoreC = Color(0xFFEA580C);
  static const Color scoreD = Color(0xFFDC2626);

  // Status financeiro — mesma cor do score de semântica equivalente.
  static const Color statusEmDia = scoreA;
  static const Color statusAtencao = scoreB;
  static const Color statusInadimplente = scoreD;
  static const Color statusVencido = scoreD;

  // Conectividade. O protótipo só define o verde do badge "ONLINE"; o
  // tom de "offline" não é especificado — optou-se por um cinza neutro,
  // em vez de vermelho, para não sugerir um erro onde não há um.
  static const Color online = scoreA;
  static const Color offline = Color(0xFF9CA3AF);

  static Color corDoScore(ScoreCliente score) => switch (score) {
    ScoreCliente.a => scoreA,
    ScoreCliente.b => scoreB,
    ScoreCliente.c => scoreC,
    ScoreCliente.d => scoreD,
  };

  static Color corDoEstoque(bool estoqueBaixo) =>
      estoqueBaixo ? statusAtencao : statusEmDia;

  /// Escolhe [textPrimary] ou branco sobre [fundo] — o que atingir pelo
  /// menos 4.5:1 de contraste (WCAG AA). O app é usado em campo, sob sol
  /// forte, então texto pouco legível não é aceitável.
  ///
  /// Contraste verificado nesta paleta: branco sobre [primary] fica em
  /// ~2.8:1 (ilegível) — por isso botões e badges no laranja primário
  /// usam [textPrimary], não branco, ao contrário do que o protótipo
  /// sugeria. O mesmo vale para os badges de score A (~5.1:1 com texto
  /// escuro), B (~7.8:1) e C (~4.7:1, no limite). Já [primaryDark] e o
  /// score D (vermelho) são escuros o bastante para exigirem texto
  /// branco (~6.8:1 e ~4.8:1, respectivamente) — texto escuro neles
  /// ficaria abaixo do mínimo.
  static Color textoContrastante(Color fundo) {
    final contrasteEscuro = _contraste(fundo, textPrimary);
    return contrasteEscuro >= 4.5 ? textPrimary : Colors.white;
  }

  static double _contraste(Color a, Color b) {
    final la = _luminancia(a) + 0.05;
    final lb = _luminancia(b) + 0.05;
    return la > lb ? la / lb : lb / la;
  }

  static double _luminancia(Color cor) =>
      0.2126 * _canalLinear(cor.r) +
      0.7152 * _canalLinear(cor.g) +
      0.0722 * _canalLinear(cor.b);

  static double _canalLinear(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}
