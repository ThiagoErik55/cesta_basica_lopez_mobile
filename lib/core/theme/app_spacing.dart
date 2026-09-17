/// Escala de espaçamento e raios do design system (KAN-12). Nenhuma tela
/// ou componente deve usar um número mágico de margem, padding ou
/// border radius — sempre referenciar estas constantes.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;
}
