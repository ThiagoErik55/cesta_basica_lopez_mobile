import '../../../core/domain/enums.dart';
import '../../cliente/data/cliente_model.dart';
import '../../rota/data/rota_model.dart';
import '../../rota/domain/associacao_rota.dart';
import '../../rota/domain/cadastro_rota.dart';
import '../../venda/data/parcela_model.dart';
import '../../venda/data/venda_model.dart';
import '../data/despesa_model.dart';
import 'agregacao_financeira.dart';
import 'periodo.dart';

/// Relatório semanal por linha de atendimento (KAN-53).
///
/// Reaproveita [TotaisFinanceiros] e [agruparTotais] da KAN-52, trocando
/// a chave de agrupamento do dia pela linha de atendimento. A regra
/// financeira é a mesma (modelo lógico §5): faturamento, custo e lucro
/// bruto por competência; "recebido" à parte, de caixa.
///
/// ## De onde vem a linha de uma venda
///
/// A venda não guarda a linha. Ela vem da **rota atual do cliente**:
/// `venda.clienteId → CLIENTE.rotaId → ROTA.linhaAtendimento`. Cliente
/// sem rota, com rota excluída, inexistente ou texto livre antigo (mesmo
/// critério de [rotaValida], KAN-46/47), e venda de cliente que não está
/// mais na lista (excluído), caem em [GrupoLinha.semLinha].
///
/// **Limitação:** se o cliente mudar de rota, as vendas antigas passam
/// para a linha nova, e o relatório de uma semana passada pode mudar
/// depois de fechado. Não há campo de linha na venda (decisão de
/// modelagem desta task, sem campo novo).
///
/// Despesas não têm linha: ficam fora das linhas, em "despesas gerais".

/// Grupo de uma linha do relatório: as linhas de atendimento do modelo
/// mais "sem linha". Existe porque a chave `null` não entra em
/// [agruparTotais].
enum GrupoLinha {
  toledo,
  regional,
  semLinha;

  static GrupoLinha daLinha(LinhaAtendimento? linha) => switch (linha) {
    LinhaAtendimento.toledo => GrupoLinha.toledo,
    LinhaAtendimento.regional => GrupoLinha.regional,
    null => GrupoLinha.semLinha,
  };

  String get rotulo => switch (this) {
    GrupoLinha.toledo => LinhaAtendimento.toledo.rotulo,
    GrupoLinha.regional => LinhaAtendimento.regional.rotulo,
    GrupoLinha.semLinha => 'Sem linha',
  };
}

/// Pagamento de parcela junto do cliente da venda, para atribuir a linha.
class PagamentoDeCliente {
  const PagamentoDeCliente({required this.clienteId, required this.pagamento});

  final String clienteId;
  final PagamentoModel pagamento;
}

/// `clienteId → grupo` de cada cliente ativo, pela rota atual dele.
/// Cliente excluído fica de fora (a venda dele cai em "sem linha").
Map<String, GrupoLinha> grupoDosClientes(
  Iterable<ClienteModel> clientes,
  Iterable<RotaModel> rotas,
) {
  final linhaDaRota = {
    for (final r in rotas)
      if (!r.deleted) r.id: r.linhaAtendimento,
  };
  return {
    for (final c in clientes)
      if (!c.deleted)
        c.id: GrupoLinha.daLinha(linhaDaRota[rotaValida(c.rotaId, rotas)]),
  };
}

/// Grupo de um cliente; cliente desconhecido é "sem linha".
GrupoLinha grupoDoCliente(String clienteId, Map<String, GrupoLinha> grupos) =>
    grupos[clienteId] ?? GrupoLinha.semLinha;

/// Uma linha de atendimento no relatório.
class LinhaRelatorio {
  const LinhaRelatorio({
    required this.grupo,
    required this.totais,
    required this.anterior,
    required this.participacaoDecimos,
    required this.vendas,
  });

  final GrupoLinha grupo;

  /// Totais da semana. As despesas ficam fora (não têm linha).
  final TotaisFinanceiros totais;

  /// Totais da semana anterior, só para a comparação.
  final TotaisFinanceiros anterior;

  /// Participação no faturamento total, em décimos de ponto percentual
  /// (0 a 1000). As linhas somam exatamente 1000 (100,0%).
  final int participacaoDecimos;

  /// Vendas da semana desta linha (sem as excluídas), para o detalhe.
  final List<VendaModel> vendas;

  String get rotulo => grupo.rotulo;

  double get participacao => participacaoDecimos / 10;

  /// Lucro bruto sobre o faturamento, em %. Zero sem faturamento (e não
  /// NaN).
  double get margem => totais.faturamento <= 0
      ? 0
      : totais.lucroBruto / totais.faturamento * 100;

  /// Sem venda na semana anterior não há com o que comparar.
  bool get temBase => anterior.vendas > 0;

  double? get variacaoFaturamento => temBase
      ? variacaoPercentual(
          atual: totais.faturamento,
          anterior: anterior.faturamento,
        )
      : null;

  double? get variacaoLucroBruto => temBase
      ? variacaoPercentual(
          atual: totais.lucroBruto,
          anterior: anterior.lucroBruto,
        )
      : null;

  /// Sem venda nem recebimento na semana.
  bool get vazia => totais.vendas == 0 && totais.recebido == 0;
}

/// Relatório de uma semana: uma [LinhaRelatorio] por linha, o total e as
/// despesas gerais.
class RelatorioSemanal {
  const RelatorioSemanal({
    required this.semana,
    required this.linhas,
    required this.total,
    required this.totalAnterior,
    required this.recebidoCompleto,
  });

  final Periodo semana;

  /// Por faturamento, da maior para a menor.
  final List<LinhaRelatorio> linhas;

  /// Soma das linhas mais as despesas gerais. Então
  /// `total.lucroLiquido = Σ lucro bruto das linhas − despesas`, e
  /// faturamento, custo e lucro bruto batem com o painel da KAN-52.
  final TotaisFinanceiros total;

  final TotaisFinanceiros totalAnterior;

  /// `false` enquanto os pagamentos de parcela não carregaram: o
  /// "recebido" só tem as vendas à vista.
  final bool recebidoCompleto;

  /// Despesas da semana, que não pertencem a nenhuma linha.
  int get despesasGerais => total.despesas;
  int get quantidadeDespesas => total.quantidadeDespesas;
  int get lucroLiquido => total.lucroLiquido;

  bool get temBase => totalAnterior.vendas > 0;

  double? get variacaoFaturamento => temBase
      ? variacaoPercentual(
          atual: total.faturamento,
          anterior: totalAnterior.faturamento,
        )
      : null;

  double? get variacaoLucroBruto => temBase
      ? variacaoPercentual(
          atual: total.lucroBruto,
          anterior: totalAnterior.lucroBruto,
        )
      : null;

  /// Sem venda, recebimento nem despesa na semana.
  bool get vazio =>
      total.vendas == 0 && total.recebido == 0 && total.despesas == 0;
}

/// Reparte 1000 décimos entre [valores] na proporção deles, pelo maior
/// resto, para a soma dar exatamente 1000. Sem total positivo, tudo zero.
List<int> repartirParticipacao(List<int> valores) {
  final total = valores.fold<int>(0, (s, v) => s + (v > 0 ? v : 0));
  if (total <= 0) return List.filled(valores.length, 0);
  final base = <int>[];
  final restos = <(int, int)>[]; // (resto, índice)
  for (var i = 0; i < valores.length; i++) {
    final v = valores[i] > 0 ? valores[i] : 0;
    base.add(v * 1000 ~/ total);
    restos.add((v * 1000 % total, i));
  }
  var faltam = 1000 - base.fold<int>(0, (s, v) => s + v);
  restos.sort((a, b) {
    final porResto = b.$1.compareTo(a.$1);
    return porResto != 0 ? porResto : a.$2.compareTo(b.$2);
  });
  for (final (_, i) in restos) {
    if (faltam <= 0) break;
    base[i]++;
    faltam--;
  }
  return base;
}

/// Monta o relatório de [semana].
///
/// [vendas], [despesas] e [pagamentos] podem cobrir mais que a semana (a
/// semana e a anterior, lidas de uma vez): cada registro é filtrado pela
/// própria data. [pagamentos] `null` = ainda não carregaram.
///
/// Toledo e Regional aparecem sempre, mesmo zeradas; "Sem linha" só
/// quando tem venda ou recebimento na semana.
RelatorioSemanal montarRelatorioSemanal({
  required Periodo semana,
  required Iterable<VendaModel> vendas,
  required Iterable<DespesaModel> despesas,
  required Map<String, GrupoLinha> grupos,
  Iterable<PagamentoDeCliente>? pagamentos,
}) {
  final todosPagamentos = pagamentos ?? const <PagamentoDeCliente>[];

  Map<GrupoLinha, TotaisFinanceiros> porGrupo(Periodo p) {
    final mapa = agruparTotais<GrupoLinha>(
      vendas: vendas.where((v) => p.contem(v.data)),
      chaveVenda: (v) => grupoDoCliente(v.clienteId, grupos),
      // Despesa não tem linha: fica de fora de todas as linhas.
      chaveDespesa: (_) => null,
    );
    for (final x in todosPagamentos.where((x) => p.contem(x.pagamento.data))) {
      final g = grupoDoCliente(x.clienteId, grupos);
      mapa[g] =
          (mapa[g] ?? TotaisFinanceiros.zero) +
          TotaisFinanceiros.doPagamento(x.pagamento);
    }
    return mapa;
  }

  TotaisFinanceiros despesasDe(Periodo p) =>
      calcularTotais(despesas: despesas.where((d) => p.contem(d.data)));

  final atuais = porGrupo(semana);
  final anteriores = porGrupo(semana.anterior);
  final vendasDaSemana = vendas
      .where((v) => semana.contem(v.data) && !v.deleted)
      .toList();

  final grupoDasLinhas = [
    GrupoLinha.toledo,
    GrupoLinha.regional,
    if ((atuais[GrupoLinha.semLinha]?.vendas ?? 0) > 0 ||
        (atuais[GrupoLinha.semLinha]?.recebido ?? 0) > 0)
      GrupoLinha.semLinha,
  ];
  final participacoes = repartirParticipacao([
    for (final g in grupoDasLinhas) atuais[g]?.faturamento ?? 0,
  ]);

  final linhas =
      [
        for (final (i, g) in grupoDasLinhas.indexed)
          LinhaRelatorio(
            grupo: g,
            totais: atuais[g] ?? TotaisFinanceiros.zero,
            anterior: anteriores[g] ?? TotaisFinanceiros.zero,
            participacaoDecimos: participacoes[i],
            vendas: [
              for (final v in vendasDaSemana)
                if (grupoDoCliente(v.clienteId, grupos) == g) v,
            ],
          ),
      ]..sort((a, b) {
        final porFaturamento = b.totais.faturamento.compareTo(
          a.totais.faturamento,
        );
        return porFaturamento != 0
            ? porFaturamento
            : a.grupo.index.compareTo(b.grupo.index);
      });

  // Totais gerais: o que sobra fora das linhas listadas também conta
  // (ex.: "sem linha" com anterior mas sem movimento agora), então somam
  // todos os grupos, não só as linhas exibidas.
  var total = despesasDe(semana);
  for (final t in atuais.values) {
    total += t;
  }
  var totalAnterior = despesasDe(semana.anterior);
  for (final t in anteriores.values) {
    totalAnterior += t;
  }

  return RelatorioSemanal(
    semana: semana,
    linhas: linhas,
    total: total,
    totalAnterior: totalAnterior,
    recebidoCompleto: pagamentos != null,
  );
}

/// Cliente no ranking de quem mais comprou na linha.
class ClienteComprador {
  const ClienteComprador({
    required this.clienteId,
    required this.nome,
    required this.vendas,
    required this.valor,
  });

  final String clienteId;
  final String nome;
  final int vendas;

  /// Faturamento em centavos.
  final int valor;
}

/// Clientes que mais compraram em [vendas] (sem as excluídas), por valor
/// e, no empate, por número de vendas e nome. Só nome: nunca o CPF.
List<ClienteComprador> clientesQueMaisCompraram(
  Iterable<VendaModel> vendas, {
  int limite = 5,
}) {
  final valores = <String, int>{};
  final contagem = <String, int>{};
  final nomes = <String, String>{};
  for (final v in vendas.where((v) => !v.deleted)) {
    valores[v.clienteId] =
        (valores[v.clienteId] ?? 0) + TotaisFinanceiros.daVenda(v).faturamento;
    contagem[v.clienteId] = (contagem[v.clienteId] ?? 0) + 1;
    nomes[v.clienteId] = v.clienteNome;
  }
  final lista = [
    for (final id in valores.keys)
      ClienteComprador(
        clienteId: id,
        nome: nomes[id]!,
        vendas: contagem[id]!,
        valor: valores[id]!,
      ),
  ];
  lista.sort((a, b) {
    final porValor = b.valor.compareTo(a.valor);
    if (porValor != 0) return porValor;
    final porVendas = b.vendas.compareTo(a.vendas);
    return porVendas != 0 ? porVendas : a.nome.compareTo(b.nome);
  });
  return lista.take(limite).toList();
}

/// Detalhe de uma linha: vendas por dia, top produtos e top clientes.
class DetalheLinha {
  const DetalheLinha({
    required this.vendasPorDia,
    required this.topProdutos,
    required this.topClientes,
  });

  final List<PontoDia> vendasPorDia;
  final List<ProdutoVendido> topProdutos;
  final List<ClienteComprador> topClientes;
}

DetalheLinha detalharLinha(LinhaRelatorio linha, Periodo semana) =>
    DetalheLinha(
      vendasPorDia: serieDiaria(periodo: semana, vendas: linha.vendas),
      topProdutos: produtosMaisVendidos(linha.vendas),
      topClientes: clientesQueMaisCompraram(linha.vendas),
    );
