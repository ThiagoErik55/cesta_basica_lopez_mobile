import '../../../core/domain/enums.dart';
import '../../venda/data/parcela_model.dart';
import '../../venda/data/venda_model.dart';
import '../data/despesa_model.dart';
import 'dia.dart';
import 'periodo.dart';

/// Converte reais em centavos inteiros, sem sobra de ponto flutuante.
int emCentavos(double reais) => (reais * 100).round();

/// Totais financeiros de um conjunto de vendas, despesas e pagamentos
/// (KAN-52). Tudo em centavos inteiros: 0,10 + 0,20 dá exatamente 0,30.
///
/// Regra do modelo lógico §5 (a mesma da KAN-51), por competência:
///
/// ```
/// lucro bruto   = faturamento − custo dos produtos
/// lucro líquido = lucro bruto − despesas
/// ```
///
/// Faturamento e custo saem da mesma fonte (as vendas), então
/// `faturamento − custo = lucro bruto` sempre. A diferença de valor das
/// trocas entra no faturamento da venda (o cliente pagou ou recebeu essa
/// diferença) e não tem custo próprio.
///
/// [recebido] é um indicador à parte, de caixa, e não entra no lucro:
/// vendas à vista mais pagamentos de parcelas.
class TotaisFinanceiros {
  const TotaisFinanceiros({
    this.faturamento = 0,
    this.custo = 0,
    this.despesas = 0,
    this.recebido = 0,
    this.vendas = 0,
    this.unidades = 0,
    this.itensSemCusto = 0,
    this.quantidadeDespesas = 0,
  });

  static const zero = TotaisFinanceiros();

  /// Totais de uma venda. Venda excluída (cancelada) não conta.
  factory TotaisFinanceiros.daVenda(VendaModel venda) {
    if (venda.deleted) return zero;
    var faturamento = emCentavos(venda.valorTotal);
    for (final t in venda.trocas) {
      faturamento += emCentavos(t.diferencaValor);
    }
    var custo = 0;
    var unidades = 0;
    var semCusto = 0;
    for (final item in venda.itens) {
      custo += item.quantidade * emCentavos(item.custoUnitario);
      unidades += item.quantidade;
      if (item.custoUnitario <= 0) semCusto++;
    }
    return TotaisFinanceiros(
      faturamento: faturamento,
      custo: custo,
      // Venda parcelada só vira dinheiro recebido pelos pagamentos.
      recebido: venda.tipo == TipoVenda.aVista
          ? emCentavos(venda.valorTotal)
          : 0,
      vendas: 1,
      unidades: unidades,
      itensSemCusto: semCusto,
    );
  }

  /// Totais de uma despesa. Despesa excluída não conta.
  factory TotaisFinanceiros.daDespesa(DespesaModel despesa) => despesa.deleted
      ? zero
      : TotaisFinanceiros(
          despesas: emCentavos(despesa.valor),
          quantidadeDespesas: 1,
        );

  /// Totais de um pagamento de parcela recebido.
  factory TotaisFinanceiros.doPagamento(PagamentoModel pagamento) =>
      TotaisFinanceiros(recebido: emCentavos(pagamento.valor));

  final int faturamento;
  final int custo;
  final int despesas;
  final int recebido;
  final int vendas;
  final int unidades;

  /// Itens vendidos com custo zero: o lucro deles sai maior que o real.
  final int itensSemCusto;
  final int quantidadeDespesas;

  int get lucroBruto => faturamento - custo;
  int get lucroLiquido => lucroBruto - despesas;

  /// Faturamento por venda, arredondado ao centavo. Zero sem vendas.
  int get ticketMedio => vendas == 0 ? 0 : (faturamento / vendas).round();

  /// Sem nenhuma venda nem despesa.
  bool get vazio => vendas == 0 && quantidadeDespesas == 0;

  TotaisFinanceiros operator +(TotaisFinanceiros o) => TotaisFinanceiros(
    faturamento: faturamento + o.faturamento,
    custo: custo + o.custo,
    despesas: despesas + o.despesas,
    recebido: recebido + o.recebido,
    vendas: vendas + o.vendas,
    unidades: unidades + o.unidades,
    itensSemCusto: itensSemCusto + o.itensSemCusto,
    quantidadeDespesas: quantidadeDespesas + o.quantidadeDespesas,
  );
}

/// Soma os totais de [vendas], [despesas] e [pagamentos] já filtrados
/// para o período desejado.
TotaisFinanceiros calcularTotais({
  Iterable<VendaModel> vendas = const [],
  Iterable<DespesaModel> despesas = const [],
  Iterable<PagamentoModel> pagamentos = const [],
}) {
  var total = TotaisFinanceiros.zero;
  for (final v in vendas) {
    total += TotaisFinanceiros.daVenda(v);
  }
  for (final d in despesas) {
    total += TotaisFinanceiros.daDespesa(d);
  }
  for (final p in pagamentos) {
    total += TotaisFinanceiros.doPagamento(p);
  }
  return total;
}

/// Agrupa os totais por uma chave qualquer: o dia agora ([chaveDoDia]),
/// a linha de atendimento na KAN-53. Cada função de chave diz a que
/// grupo o registro pertence; `null` deixa o registro de fora.
Map<K, TotaisFinanceiros> agruparTotais<K>({
  Iterable<VendaModel> vendas = const [],
  Iterable<DespesaModel> despesas = const [],
  Iterable<PagamentoModel> pagamentos = const [],
  required K? Function(VendaModel) chaveVenda,
  required K? Function(DespesaModel) chaveDespesa,
  K? Function(PagamentoModel)? chavePagamento,
}) {
  final grupos = <K, TotaisFinanceiros>{};
  void somar(K? chave, TotaisFinanceiros t) {
    if (chave == null) return;
    grupos[chave] = (grupos[chave] ?? TotaisFinanceiros.zero) + t;
  }

  for (final v in vendas) {
    somar(chaveVenda(v), TotaisFinanceiros.daVenda(v));
  }
  for (final d in despesas) {
    somar(chaveDespesa(d), TotaisFinanceiros.daDespesa(d));
  }
  if (chavePagamento != null) {
    for (final p in pagamentos) {
      somar(chavePagamento(p), TotaisFinanceiros.doPagamento(p));
    }
  }
  return grupos;
}

/// Chave de agrupamento por dia de calendário.
DateTime chaveDoDia(DateTime data) => inicioDoDia(data);

/// Totais de um dia do período.
class PontoDia {
  const PontoDia(this.dia, this.totais);
  final DateTime dia;
  final TotaisFinanceiros totais;
}

/// Um ponto por dia do [periodo], com os dias sem movimento zerados.
List<PontoDia> serieDiaria({
  required Periodo periodo,
  Iterable<VendaModel> vendas = const [],
  Iterable<DespesaModel> despesas = const [],
  Iterable<PagamentoModel> pagamentos = const [],
}) {
  final porDia = agruparTotais<DateTime>(
    vendas: vendas,
    despesas: despesas,
    pagamentos: pagamentos,
    chaveVenda: (v) => chaveDoDia(v.data),
    chaveDespesa: (d) => chaveDoDia(d.data),
    chavePagamento: (p) => chaveDoDia(p.data),
  );
  return [
    for (final dia in periodo.diasDoPeriodo)
      PontoDia(dia, porDia[dia] ?? TotaisFinanceiros.zero),
  ];
}

/// Variação percentual de [anterior] para [atual]. `null` quando o
/// anterior é zero (não há base de comparação). Usa o módulo do anterior
/// para o sinal indicar a direção mesmo com lucro negativo.
double? variacaoPercentual({required int atual, required int anterior}) {
  if (anterior == 0) return null;
  return (atual - anterior) / anterior.abs() * 100;
}

/// Período atual comparado ao anterior de mesma duração.
class ComparacaoPeriodo {
  ComparacaoPeriodo({required this.atual, required this.anterior});

  final TotaisFinanceiros atual;
  final TotaisFinanceiros anterior;

  /// Sem movimento no período anterior não há com o que comparar.
  bool get temBase => !anterior.vazio;

  double? get variacaoFaturamento => _variacao((t) => t.faturamento);
  double? get variacaoDespesas => _variacao((t) => t.despesas);
  double? get variacaoLucroLiquido => _variacao((t) => t.lucroLiquido);

  double? _variacao(int Function(TotaisFinanceiros) campo) => temBase
      ? variacaoPercentual(atual: campo(atual), anterior: campo(anterior))
      : null;
}

/// Produto no ranking de mais vendidos.
class ProdutoVendido {
  const ProdutoVendido({
    required this.produtoId,
    required this.nome,
    required this.quantidade,
    required this.faturamento,
  });

  final String produtoId;
  final String nome;
  final int quantidade;

  /// Em centavos: quantidade × preço praticado na venda.
  final int faturamento;
}

/// Produtos mais vendidos de [vendas] (sem as excluídas), por quantidade
/// e, no empate, por faturamento. Usa só o que já está nas vendas.
List<ProdutoVendido> produtosMaisVendidos(
  Iterable<VendaModel> vendas, {
  int limite = 5,
}) {
  final quantidades = <String, int>{};
  final valores = <String, int>{};
  final nomes = <String, String>{};
  for (final venda in vendas.where((v) => !v.deleted)) {
    for (final item in venda.itens) {
      quantidades[item.produtoId] =
          (quantidades[item.produtoId] ?? 0) + item.quantidade;
      valores[item.produtoId] =
          (valores[item.produtoId] ?? 0) +
          item.quantidade * emCentavos(item.precoUnitario);
      nomes[item.produtoId] = item.nome;
    }
  }
  final lista = [
    for (final id in quantidades.keys)
      ProdutoVendido(
        produtoId: id,
        nome: nomes[id]!,
        quantidade: quantidades[id]!,
        faturamento: valores[id]!,
      ),
  ];
  lista.sort((a, b) {
    final porQuantidade = b.quantidade.compareTo(a.quantidade);
    if (porQuantidade != 0) return porQuantidade;
    final porValor = b.faturamento.compareTo(a.faturamento);
    return porValor != 0 ? porValor : a.nome.compareTo(b.nome);
  });
  return lista.take(limite).toList();
}

/// Painel financeiro de um período (KAN-52), já com a comparação, a
/// série diária e os detalhamentos.
class PainelFinanceiro {
  const PainelFinanceiro({
    required this.periodo,
    required this.comparacao,
    required this.serie,
    required this.topProdutos,
    required this.recebidoCompleto,
  });

  final Periodo periodo;
  final ComparacaoPeriodo comparacao;
  final List<PontoDia> serie;
  final List<ProdutoVendido> topProdutos;

  /// `false` enquanto os pagamentos de parcelas não foram carregados: o
  /// [TotaisFinanceiros.recebido] só tem as vendas à vista.
  final bool recebidoCompleto;

  TotaisFinanceiros get totais => comparacao.atual;

  /// Dias do período com despesa, em ordem.
  List<PontoDia> get despesasPorDia => [
    for (final p in serie)
      if (p.totais.quantidadeDespesas > 0) p,
  ];
}

/// Monta o painel de [periodo] a partir de listas que podem cobrir um
/// intervalo maior (o período e o anterior): cada registro é filtrado
/// pela própria data. [pagamentos] são os de parcelas; `null` se ainda
/// não carregaram.
PainelFinanceiro montarPainel({
  required Periodo periodo,
  required Iterable<VendaModel> vendas,
  required Iterable<DespesaModel> despesas,
  Iterable<PagamentoModel>? pagamentos,
}) {
  final todosPagamentos = pagamentos ?? const <PagamentoModel>[];
  TotaisFinanceiros totaisDe(Periodo p) => calcularTotais(
    vendas: vendas.where((v) => p.contem(v.data)),
    despesas: despesas.where((d) => p.contem(d.data)),
    pagamentos: todosPagamentos.where((x) => p.contem(x.data)),
  );
  final vendasAtuais = vendas.where((v) => periodo.contem(v.data)).toList();
  return PainelFinanceiro(
    periodo: periodo,
    comparacao: ComparacaoPeriodo(
      atual: totaisDe(periodo),
      anterior: totaisDe(periodo.anterior),
    ),
    serie: serieDiaria(
      periodo: periodo,
      vendas: vendasAtuais,
      despesas: despesas.where((d) => periodo.contem(d.data)),
      pagamentos: todosPagamentos.where((x) => periodo.contem(x.data)),
    ),
    topProdutos: produtosMaisVendidos(vendasAtuais),
    recebidoCompleto: pagamentos != null,
  );
}
