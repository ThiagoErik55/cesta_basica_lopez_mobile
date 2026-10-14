import '../../produto/data/produto_model.dart';

/// Produto escolhido na nova venda (KAN-25), ainda não gravado. Vira um
/// ItemVenda só ao finalizar (KAN-27).
class ItemCarrinho {
  const ItemCarrinho({required this.produto, required this.quantidade});

  final ProdutoModel produto;
  final int quantidade;

  double get subtotal => quantidade * produto.preco;

  /// Quantidade maior que o estoque em cache. Não bloqueia a venda
  /// (restrição do levantamento de requisitos), só gera aviso na tela.
  bool get excedeEstoque => quantidade > produto.estoqueAtual;

  ItemCarrinho comQuantidade(int nova) =>
      ItemCarrinho(produto: produto, quantidade: nova);
}

/// Soma dos subtotais do carrinho.
double totalCarrinho(Iterable<ItemCarrinho> itens) =>
    itens.fold<double>(0, (soma, i) => soma + i.subtotal);

/// Quantidade total de unidades no carrinho.
int unidadesCarrinho(Iterable<ItemCarrinho> itens) =>
    itens.fold<int>(0, (soma, i) => soma + i.quantidade);
