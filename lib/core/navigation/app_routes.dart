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

  /// Detalhes de uma venda registrada (KAN-27, KAN-28, KAN-29). Recebe o
  /// id da venda (String) em `arguments` do Navigator.pushNamed.
  static const String detalheVenda = '/vendas/detalhe';

  /// Cadastro de cliente (RF01), aberto pelo FAB da aba Clientes.
  static const String cadastroCliente = '/clientes/novo';

  /// Detalhes do cliente. Recebe o id do cliente (String) em
  /// `arguments` do Navigator.pushNamed.
  static const String detalheCliente = '/clientes/detalhe';

  /// Edição dos dados cadastrais do cliente (KAN-17). Recebe o
  /// ClienteModel a editar em `arguments` do Navigator.pushNamed.
  static const String editarCliente = '/clientes/editar';
}
