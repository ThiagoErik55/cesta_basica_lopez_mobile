import '../../../core/domain/enums.dart';
import '../../../core/utils/texto.dart';
import '../../produto/data/produto_model.dart';
import '../data/movimento_estoque_model.dart';

/// Situação do estoque de um produto (KAN-41).
enum SituacaoEstoque { normal, baixo, semEstoque }

/// - `semEstoque`: saldo menor ou igual a zero (inclui o negativo, de
///   venda acima do estoque registrado).
/// - `baixo`: saldo positivo, mas menor ou igual ao mínimo.
/// - `normal`: acima do mínimo. Com mínimo 0, nunca é `baixo`.
SituacaoEstoque situacaoDoEstoque({
  required int estoqueAtual,
  required int estoqueMinimo,
}) {
  if (estoqueAtual <= 0) return SituacaoEstoque.semEstoque;
  if (estoqueAtual <= estoqueMinimo) return SituacaoEstoque.baixo;
  return SituacaoEstoque.normal;
}

/// Saldo negativo: venda acima do estoque registrado.
bool estoqueNegativo(int estoqueAtual) => estoqueAtual < 0;

/// Valor em estoque do produto: `estoqueAtual × custoAtual`, calculado
/// em centavos para não acumular erro de ponto flutuante.
double calcularValorEmEstoque({
  required int estoqueAtual,
  required double custoAtual,
}) => (custoAtual * 100).round() * estoqueAtual / 100;

/// Produto com os valores derivados que a tela de estoque mostra.
class ItemEstoque {
  const ItemEstoque({
    required this.produto,
    required this.situacao,
    required this.valorEmEstoque,
  });

  factory ItemEstoque.de(ProdutoModel p) => ItemEstoque(
    produto: p,
    situacao: situacaoDoEstoque(
      estoqueAtual: p.estoqueAtual,
      estoqueMinimo: p.estoqueMinimo,
    ),
    valorEmEstoque: calcularValorEmEstoque(
      estoqueAtual: p.estoqueAtual,
      custoAtual: p.custoAtual,
    ),
  );

  final ProdutoModel produto;
  final SituacaoEstoque situacao;

  /// `estoqueAtual × custoAtual`; fica negativo se o saldo é negativo.
  final double valorEmEstoque;

  bool get negativo => estoqueNegativo(produto.estoqueAtual);
}

/// Itens de estoque dos produtos ativos (exclusão lógica ignorada).
List<ItemEstoque> montarItensEstoque(Iterable<ProdutoModel> produtos) => [
  for (final p in produtos)
    if (!p.deleted) ItemEstoque.de(p),
];

class ResumoEstoque {
  const ResumoEstoque({
    required this.totalProdutos,
    required this.semEstoque,
    required this.estoqueBaixo,
    required this.valorTotal,
  });

  final int totalProdutos;

  /// Inclui os produtos com saldo negativo.
  final int semEstoque;
  final int estoqueBaixo;

  /// Soma de `estoqueAtual × custoAtual`, ignorando saldos negativos.
  final double valorTotal;
}

ResumoEstoque resumirEstoque(List<ItemEstoque> itens) {
  var semEstoque = 0;
  var baixo = 0;
  var centavos = 0;
  for (final i in itens) {
    switch (i.situacao) {
      case SituacaoEstoque.semEstoque:
        semEstoque++;
      case SituacaoEstoque.baixo:
        baixo++;
      case SituacaoEstoque.normal:
        break;
    }
    if (i.produto.estoqueAtual > 0) {
      centavos += (i.valorEmEstoque * 100).round();
    }
  }
  return ResumoEstoque(
    totalProdutos: itens.length,
    semEstoque: semEstoque,
    estoqueBaixo: baixo,
    valorTotal: centavos / 100,
  );
}

/// Categorias existentes (sem repetição, em ordem alfabética).
List<String> categoriasDoEstoque(List<ItemEstoque> itens) => {
  for (final i in itens)
    if (i.produto.categoria.isNotEmpty) i.produto.categoria,
}.toList()..sort((a, b) => normalizarBusca(a).compareTo(normalizarBusca(b)));

/// Filtra por situação, categoria e busca (nome, marca ou código, sem
/// diferenciar maiúsculas nem acentos). Filtro `null` não restringe.
/// [apenasAlertas] deixa só os produtos em alerta (ver [emAlerta]).
List<ItemEstoque> filtrarEstoque(
  List<ItemEstoque> itens, {
  SituacaoEstoque? situacao,
  String? categoria,
  String termo = '',
  bool apenasAlertas = false,
}) {
  final busca = normalizarBusca(termo.trim());
  return [
    for (final i in itens)
      if ((situacao == null || i.situacao == situacao) &&
          (!apenasAlertas || emAlerta(i)) &&
          (categoria == null || i.produto.categoria == categoria) &&
          (busca.isEmpty ||
              normalizarBusca(i.produto.nome).contains(busca) ||
              normalizarBusca(i.produto.marca).contains(busca) ||
              normalizarBusca(i.produto.codigo).contains(busca)))
        i,
  ];
}

/// Sem estoque primeiro, depois baixo, depois normal; por nome dentro de
/// cada grupo.
List<ItemEstoque> ordenarEstoque(List<ItemEstoque> itens) =>
    [...itens]..sort((a, b) {
      final grupo = _ordem(a.situacao).compareTo(_ordem(b.situacao));
      if (grupo != 0) return grupo;
      final nome = normalizarBusca(a.produto.nome)
          .compareTo(normalizarBusca(b.produto.nome));
      return nome != 0 ? nome : a.produto.id.compareTo(b.produto.id);
    });

int _ordem(SituacaoEstoque s) => switch (s) {
  SituacaoEstoque.semEstoque => 0,
  SituacaoEstoque.baixo => 1,
  SituacaoEstoque.normal => 2,
};

// --- Alerta de estoque baixo (KAN-44) ---------------------------------
// Usa a mesma situação derivada de [situacaoDoEstoque]: não há uma
// segunda regra de "o que é estoque baixo".

/// Produto em alerta: estoque baixo, sem estoque ou negativo. Estoque
/// igual ao mínimo conta como baixo (regra de [situacaoDoEstoque]) e,
/// com mínimo 0, só `semEstoque`/negativo alertam.
bool emAlerta(ItemEstoque item) => item.situacao != SituacaoEstoque.normal;

/// Quantos produtos estão em alerta.
int contarAlertas(Iterable<ItemEstoque> itens) => itens.where(emAlerta).length;

/// Unidades que faltam para atingir o mínimo; nunca negativo. Saldo
/// negativo conta a partir do saldo (mín. 10, saldo -3 → faltam 13).
int faltamParaMinimo({required int estoqueAtual, required int estoqueMinimo}) {
  final falta = estoqueMinimo - estoqueAtual;
  return falta > 0 ? falta : 0;
}

/// Relação saldo/mínimo, para ordenar por gravidade (menor = mais grave).
/// Com mínimo 0 não há divisão: vale o próprio saldo (que, num alerta, é
/// zero ou negativo).
double _relacaoComMinimo(ProdutoModel p) => p.estoqueMinimo > 0
    ? p.estoqueAtual / p.estoqueMinimo
    : p.estoqueAtual.toDouble();

/// Alertas por gravidade: negativo e sem estoque primeiro, depois baixo;
/// em cada grupo, menor relação saldo/mínimo e depois nome. Produtos
/// normais, se houver, ficam por último.
List<ItemEstoque> ordenarAlertas(List<ItemEstoque> itens) =>
    [...itens]..sort((a, b) {
      final grupo = _ordem(a.situacao).compareTo(_ordem(b.situacao));
      if (grupo != 0) return grupo;
      final relacao = _relacaoComMinimo(a.produto)
          .compareTo(_relacaoComMinimo(b.produto));
      if (relacao != 0) return relacao;
      final nome = normalizarBusca(a.produto.nome)
          .compareTo(normalizarBusca(b.produto.nome));
      return nome != 0 ? nome : a.produto.id.compareTo(b.produto.id);
    });

/// Texto de quanto falta para o mínimo no card do alerta; `null` fora de
/// alerta ou sem mínimo definido (mínimo 0 e nada a completar).
String? textoFaltaParaMinimo(ItemEstoque item) {
  if (!emAlerta(item)) return null;
  final falta = faltamParaMinimo(
    estoqueAtual: item.produto.estoqueAtual,
    estoqueMinimo: item.produto.estoqueMinimo,
  );
  if (falta > 0) {
    return 'Faltam $falta un. para o mínimo (${item.produto.estoqueMinimo})';
  }
  return item.produto.estoqueMinimo > 0 ? 'No limite do mínimo' : null;
}

/// Texto da faixa da aba Produtos; `null` sem alertas.
String? textoFaixaAlertas(int alertas) {
  if (alertas <= 0) return null;
  return alertas == 1
      ? '1 produto com estoque baixo ou zerado'
      : '$alertas produtos com estoque baixo ou zerado';
}

/// Aviso do SnackBar depois de uma entrada, quando o produto continua em
/// alerta com o novo saldo; `null` se saiu do alerta.
String? avisoAposEntrada({
  required int estoqueApos,
  required int estoqueMinimo,
}) {
  final situacao = situacaoDoEstoque(
    estoqueAtual: estoqueApos,
    estoqueMinimo: estoqueMinimo,
  );
  if (situacao == SituacaoEstoque.normal) return null;
  final falta = faltamParaMinimo(
    estoqueAtual: estoqueApos,
    estoqueMinimo: estoqueMinimo,
  );
  if (falta > 0) return 'Ainda abaixo do mínimo: faltam $falta un.';
  return situacao == SituacaoEstoque.baixo
      ? 'Estoque no limite do mínimo.'
      : 'O produto continua sem estoque.';
}

/// Movimentos ativos, do mais recente para o mais antigo. A consulta do
/// Firestore não ordena (evita índice composto): a ordem é feita aqui.
List<MovimentoEstoqueModel> ordenarMovimentos(
  Iterable<MovimentoEstoqueModel> movimentos,
) =>
    [
      for (final m in movimentos)
        if (!m.deleted) m,
    ]..sort((a, b) {
      final porData = b.data.compareTo(a.data);
      return porData != 0 ? porData : b.id.compareTo(a.id);
    });

extension RotuloTipoMovimento on TipoMovimento {
  String get rotulo => switch (this) {
    TipoMovimento.entrada => 'Entrada',
    TipoMovimento.saida => 'Saída',
    TipoMovimento.troca => 'Troca',
  };
}
