import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Estilos de texto do design system (KAN-12). Usa a fonte padrão da
/// plataforma — nenhuma fonte customizada foi adicionada nesta task.
class AppTextStyles {
  const AppTextStyles._();

  /// Título grande da tela, ex. "Agenda de Hoje".
  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Cabeçalho de seção, ex. "Clientes a Visitar".
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Nome do cliente ou do produto no card.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Endereço, marca — linha secundária do card.
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Texto corrido.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Texto pequeno e secundário, ex. "Última compra há 5 dias".
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Valores monetários em linha, peso maior que o corpo.
  static const TextStyle money = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Valor de destaque, ex. painel financeiro do dia.
  static const TextStyle moneyLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// Texto dentro de badges. Sem cor fixa: o fundo do badge muda (score,
  /// status, conectividade), então quem monta o badge aplica a cor via
  /// AppColors.textoContrastante para garantir 4.5:1 de contraste.
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  /// Texto de botão. Sem cor fixa pela mesma razão do badge — o laranja
  /// primário exige texto escuro e o marrom escuro exige texto branco
  /// (ver AppColors.textoContrastante).
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
