/// Dados cadastrais preenchidos no formulário de produto (KAN-23).
///
/// `codigo` não entra aqui: é gerado a partir do id, como o código do
/// cliente (ver SalvarProdutoNotifier.cadastrar). `estoqueAtual` também
/// fica de fora — é cache derivado de movimentosEstoque (ADR 001), não
/// um campo editável pelo cadastro.
class DadosCadastraisProduto {
  const DadosCadastraisProduto({
    required this.nome,
    required this.marca,
    required this.categoria,
    required this.preco,
    required this.custoAtual,
    required this.estoqueMinimo,
  });

  final String nome;
  final String marca;
  final String categoria;
  final double preco;
  final double custoAtual;
  final int estoqueMinimo;
}
