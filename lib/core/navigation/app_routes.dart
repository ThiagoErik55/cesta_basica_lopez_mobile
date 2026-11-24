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

  /// Controle de promissórias (KAN-34). Opcionalmente recebe o id do
  /// cliente (String) em `arguments` para listar só as dele.
  static const String promissorias = '/promissorias';

    /// Despesas do vendedor (KAN-50, RF27), aberta pelo Financeiro.
  static const String despesas = '/financeiro/despesas';

  /// Comprovante de um pagamento (KAN-36). Recebe um `ComprovanteArgs`
  /// (venda, parcela e pagamento) em `arguments`.
  static const String comprovante = '/comprovante';

  /// Nota provisória de compra e venda (KAN-37). Recebe o id da venda
  /// (String) em `arguments`.
  static const String notaProvisoria = '/vendas/nota-provisoria';

  /// Coleta da assinatura do cliente (KAN-38). Recebe o id da venda
  /// (String) em `arguments`.
  static const String assinatura = '/vendas/assinatura';

  /// Controle de estoque (KAN-41): consulta do estoque dos produtos, com
  /// o histórico de movimentações. Opcionalmente recebe um
  /// `EstoqueRotaArgs` em `arguments` (KAN-44) para abrir já filtrada em
  /// alertas.
  static const String estoque = '/estoque';

  /// Cadastro de rotas (KAN-45, RF06): lista, criação, edição e exclusão
  /// lógica. Aberta pelo ícone "Rotas" da aba Agenda.
  static const String rotas = '/rotas';

  /// Cadastro de cliente (RF01), aberto pelo FAB da aba Clientes.
  static const String cadastroCliente = '/clientes/novo';

  /// Detalhes do cliente. Recebe o id do cliente (String) em
  /// `arguments` do Navigator.pushNamed.
  static const String detalheCliente = '/clientes/detalhe';

  /// Edição dos dados cadastrais do cliente (KAN-17). Recebe o
  /// ClienteModel a editar em `arguments` do Navigator.pushNamed.
  static const String editarCliente = '/clientes/editar';

  /// Cadastro de produto (KAN-23), aberto pelo FAB da aba Produtos.
  static const String cadastroProduto = '/produtos/novo';

  /// Edição de um produto. Recebe o ProdutoModel a editar em
  /// `arguments` do Navigator.pushNamed.
  static const String editarProduto = '/produtos/editar';
}
