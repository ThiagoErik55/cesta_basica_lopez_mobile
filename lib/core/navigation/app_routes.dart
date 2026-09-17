/// Rotas nomeadas registradas no MaterialApp (KAN-10, KAN-12).
class AppRoutes {
  const AppRoutes._();

  /// Vitrine dos componentes do design system (KAN-12) — fora da
  /// navegação principal, acessada só por rota nomeada.
  static const String showcase = '/showcase';

  /// Fluxo de nova venda, aberto pelo botão central da navegação
  /// principal. Não é uma aba: uma venda tem começo e fim, então é
  /// empilhada sobre a navegação atual (Navigator.pushNamed), e não uma
  /// posição fixa do IndexedStack do MainShell.
  static const String novaVenda = '/nova-venda';
}
