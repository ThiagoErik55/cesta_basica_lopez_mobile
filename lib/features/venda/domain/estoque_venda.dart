import '../../estoque/domain/controle_estoque.dart';
import '../../estoque/domain/regra_estoque.dart';
import 'carrinho.dart';

/// Quantidade total pedida de cada produto (por id). Se o mesmo produto
/// aparece em mais de uma linha, as quantidades somam.
Map<String, int> somarQuantidadesPorProduto(Iterable<ItemCarrinho> itens) {
  final soma = <String, int>{};
  for (final i in itens) {
    soma.update(
      i.produto.id,
      (q) => q + i.quantidade,
      ifAbsent: () => i.quantidade,
    );
  }
  return soma;
}

/// Produto cuja quantidade pedida passa do estoque registrado.
class ItemAcimaDoEstoque {
  const ItemAcimaDoEstoque({
    required this.produtoId,
    required this.nome,
    required this.quantidade,
    required this.estoque,
  });

  final String produtoId;
  final String nome;

  /// Total pedido do produto na venda.
  final int quantidade;

  /// Estoque registrado; pode ser zero ou negativo.
  final int estoque;

  /// Unidades que faltam. Saldo zero ou negativo não conta como
  /// disponível, então faltam todas as pedidas.
  int get faltam => quantidade - (estoque > 0 ? estoque : 0);
}

/// Produtos pedidos acima do estoque registrado, na ordem do carrinho.
/// Quantidade igual ao estoque é permitida; estoque zero ou negativo
/// deixa qualquer quantidade acima.
List<ItemAcimaDoEstoque> itensAcimaDoEstoque(Iterable<ItemCarrinho> itens) {
  final soma = somarQuantidadesPorProduto(itens);
  final vistos = <String>{};
  return [
    for (final i in itens)
      if (vistos.add(i.produto.id) &&
          soma[i.produto.id]! > i.produto.estoqueAtual)
        ItemAcimaDoEstoque(
          produtoId: i.produto.id,
          nome: i.produto.nome,
          quantidade: soma[i.produto.id]!,
          estoque: i.produto.estoqueAtual,
        ),
  ];
}

/// Texto abaixo do item na venda: "Estoque: 3 · faltam 2".
String textoFaltaEstoque(ItemAcimaDoEstoque item) =>
    'Estoque: ${item.estoque} · faltam ${item.faltam}';

/// Mensagem por produto quando a [RegraEstoque] bloqueia a venda.
String mensagemBloqueioEstoque(ItemAcimaDoEstoque item) =>
    '${item.nome}: pedido ${item.quantidade}, estoque ${item.estoque} '
    '(faltam ${item.faltam}).';

/// Mensagens que impedem finalizar a venda por falta de estoque; vazia se
/// a regra não bloqueia ou se nada passa do estoque.
List<String> impedimentosDeEstoque(
  Iterable<ItemCarrinho> itens,
  RegraEstoque regra,
) => regra.bloquearVendaSemEstoque
    ? [for (final i in itensAcimaDoEstoque(itens)) mensagemBloqueioEstoque(i)]
    : const [];

/// Aviso único do resumo da venda quando há itens acima do estoque e a
/// venda é permitida (regra sem bloqueio); `null` caso contrário. Com
/// bloqueio ligado vale a mensagem de impedimento.
String? avisoResumoEstoque(Iterable<ItemCarrinho> itens, RegraEstoque regra) {
  if (regra.bloquearVendaSemEstoque) return null;
  final acima = itensAcimaDoEstoque(itens);
  if (acima.isEmpty) return null;
  final n = acima.length;
  return n == 1
      ? '1 item acima do estoque registrado: o estoque ficará negativo.'
      : '$n itens acima do estoque registrado: o estoque ficará negativo.';
}

/// Produto que, depois da venda, fica com estoque baixo ou zerado, sem
/// ficar negativo (KAN-44). O negativo já tem o aviso de
/// [ItemAcimaDoEstoque].
class ItemEstoqueBaixoAposVenda {
  const ItemEstoqueBaixoAposVenda({
    required this.produtoId,
    required this.nome,
    required this.estoqueApos,
    required this.situacao,
  });

  final String produtoId;
  final String nome;

  /// Saldo depois da venda; nunca negativo aqui.
  final int estoqueApos;

  /// Situação do saldo depois da venda, pela mesma regra da tela Estoque.
  final SituacaoEstoque situacao;
}

/// Produtos que a venda deixa em alerta (estoque baixo ou exatamente
/// zero), na ordem do carrinho. Reaproveita a soma por produto da
/// KAN-43 e [situacaoDoEstoque]; estoque igual ao mínimo conta como
/// baixo, como na tela Estoque.
List<ItemEstoqueBaixoAposVenda> itensComEstoqueBaixoAposVenda(
  Iterable<ItemCarrinho> itens,
) {
  final soma = somarQuantidadesPorProduto(itens);
  final vistos = <String>{};
  final avisos = <ItemEstoqueBaixoAposVenda>[];
  for (final i in itens) {
    final p = i.produto;
    if (!vistos.add(p.id)) continue;
    final apos = p.estoqueAtual - soma[p.id]!;
    if (apos < 0) continue;
    final situacao = situacaoDoEstoque(
      estoqueAtual: apos,
      estoqueMinimo: p.estoqueMinimo,
    );
    if (situacao == SituacaoEstoque.normal) continue;
    avisos.add(
      ItemEstoqueBaixoAposVenda(
        produtoId: p.id,
        nome: p.nome,
        estoqueApos: apos,
        situacao: situacao,
      ),
    );
  }
  return avisos;
}

/// "Arroz ficará com estoque baixo (3 un.)" ou "Arroz ficará sem estoque".
String textoEstoqueBaixoAposVenda(ItemEstoqueBaixoAposVenda item) =>
    item.situacao == SituacaoEstoque.baixo
    ? '${item.nome} ficará com estoque baixo (${item.estoqueApos} un.)'
    : '${item.nome} ficará sem estoque';

/// Avisos informativos do resumo da venda; vazia se nada fica em alerta.
/// Não bloqueia a venda.
List<String> avisosEstoqueBaixoAposVenda(Iterable<ItemCarrinho> itens) => [
  for (final i in itensComEstoqueBaixoAposVenda(itens))
    textoEstoqueBaixoAposVenda(i),
];
