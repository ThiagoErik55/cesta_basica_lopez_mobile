import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/agregacao_financeira.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _quarta = DateTime(2026, 11, 18, 10);

ItemVenda _item({
  String produto = 'p1',
  String nome = 'Cesta',
  int quantidade = 1,
  double preco = 100,
  double custo = 60,
}) => ItemVenda(
  id: '$produto-$quantidade-$preco',
  produtoId: produto,
  nome: nome,
  quantidade: quantidade,
  precoUnitario: preco,
  custoUnitario: custo,
);

VendaModel _venda(
  String id, {
  DateTime? data,
  TipoVenda tipo = TipoVenda.aVista,
  List<ItemVenda>? itens,
  List<TrocaItem> trocas = const [],
  bool deleted = false,
}) {
  final lista = itens ?? [_item()];
  return VendaModel(
    id: id,
    clienteId: 'c1',
    clienteNome: 'Maria',
    vendedorUid: 'u1',
    numeroNota: 1,
    data: data ?? _quarta,
    itens: lista,
    trocas: trocas,
    valorTotal: lista.fold<double>(0, (s, i) => s + i.subtotal),
    tipo: tipo,
    updatedAt: _quarta,
    deleted: deleted,
  );
}

TrocaItem _troca(double diferenca) => TrocaItem(
  id: 't',
  itemOriginalId: 'i',
  produtoNovoId: 'p2',
  produtoNovoNome: 'Outro',
  quantidade: 1,
  diferencaValor: diferenca,
  data: _quarta,
);

DespesaModel _despesa(double valor, {DateTime? data, bool deleted = false}) =>
    DespesaModel(
      id: '$valor${data ?? ''}',
      vendedorUid: 'u1',
      descricao: 'Combustível',
      valor: valor,
      data: data ?? _quarta,
      updatedAt: _quarta,
      deleted: deleted,
    );

PagamentoModel _pagamento(double valor, DateTime data) => PagamentoModel(
  id: 'pg$valor',
  valor: valor,
  data: data,
  forma: FormaPagamento.pix,
);

void main() {
  group('totais', () {
    test('lucro líquido = faturamento − custo − despesas, em centavos', () {
      final t = calcularTotais(
        vendas: [
          _venda('v1', itens: [_item(quantidade: 2, preco: 130, custo: 90)]),
        ],
        despesas: [_despesa(30), _despesa(12.5)],
      );
      expect(t.faturamento, 26000);
      expect(t.custo, 18000);
      expect(t.lucroBruto, 8000);
      expect(t.despesas, 4250);
      expect(t.lucroLiquido, 3750);
      expect(t.vendas, 1);
      expect(t.unidades, 2);
    });

    test('sem erro de ponto flutuante: 0,10 + 0,20 = 0,30', () {
      final t = calcularTotais(despesas: [_despesa(0.1), _despesa(0.2)]);
      expect(t.despesas, 30);
    });

    test('venda à vista e parcelada entram no faturamento e no lucro', () {
      final t = calcularTotais(
        vendas: [
          _venda('v1'),
          _venda('v2', tipo: TipoVenda.parcelado),
        ],
      );
      expect(t.faturamento, 20000);
      expect(t.lucroBruto, 8000);
      expect(t.vendas, 2);
    });

    test('venda cancelada (deleted) não conta em nada', () {
      final t = calcularTotais(
        vendas: [_venda('v1'), _venda('v2', deleted: true)],
        despesas: [_despesa(50, deleted: true)],
      );
      expect(t.vendas, 1);
      expect(t.faturamento, 10000);
      expect(t.despesas, 0);
      expect(t.quantidadeDespesas, 0);
    });

    test('troca com diferença de valor: faturamento − custo = lucro bruto', () {
      for (final dif in [15.0, -8.5, 0.0]) {
        final t = calcularTotais(
          vendas: [
            _venda('v1', trocas: [_troca(dif)]),
          ],
        );
        expect(t.faturamento, 10000 + (dif * 100).round());
        expect(t.faturamento - t.custo, t.lucroBruto);
        expect(t.custo, 6000);
      }
    });

    test('lucro bate com margemBruta da venda', () {
      final v = _venda('v1', trocas: [_troca(15)]);
      expect(
        calcularTotais(vendas: [v]).lucroBruto,
        (v.margemBruta * 100).round(),
      );
    });

    test('item sem custo é contado e infla o lucro', () {
      final t = calcularTotais(
        vendas: [
          _venda(
            'v1',
            itens: [
              _item(custo: 0),
              _item(produto: 'p2'),
            ],
          ),
        ],
      );
      expect(t.itensSemCusto, 1);
      expect(t.lucroBruto, 14000);
    });

    test('despesa zero não muda o total', () {
      final t = calcularTotais(despesas: [_despesa(0), _despesa(10)]);
      expect(t.despesas, 1000);
    });

    test('dia sem movimento fica zerado e vazio', () {
      final t = calcularTotais();
      expect(t.vazio, isTrue);
      expect(t.lucroLiquido, 0);
      expect(t.ticketMedio, 0);
    });

    test('lucro líquido negativo quando despesas passam do lucro', () {
      final t = calcularTotais(
        vendas: [_venda('v1')],
        despesas: [_despesa(100)],
      );
      expect(t.lucroLiquido, -6000);
    });

    test('ticket médio com 0 vendas é 0, sem dividir por zero', () {
      expect(calcularTotais(despesas: [_despesa(10)]).ticketMedio, 0);
    });

    test('ticket médio arredonda ao centavo', () {
      final t = calcularTotais(
        vendas: [
          _venda('v1', itens: [_item(preco: 10, custo: 5)]),
          _venda('v2', itens: [_item(preco: 10, custo: 5)]),
          _venda('v3', itens: [_item(preco: 10.01, custo: 5)]),
        ],
      );
      expect(t.ticketMedio, 1000); // 3001 / 3 = 1000,33
    });
  });

  group('recebido no período', () {
    test('à vista conta o valor; parcelada só pelos pagamentos', () {
      final t = calcularTotais(
        vendas: [
          _venda('v1'),
          _venda('v2', tipo: TipoVenda.parcelado),
        ],
        pagamentos: [_pagamento(40, _quarta)],
      );
      expect(t.recebido, 10000 + 4000);
      // O lucro não muda com o recebido.
      expect(t.lucroBruto, 8000);
    });

    test('pagamento parcial entra pelo valor pago', () {
      final t = calcularTotais(pagamentos: [_pagamento(12.34, _quarta)]);
      expect(t.recebido, 1234);
    });

    test('venda à vista cancelada não é recebida', () {
      expect(calcularTotais(vendas: [_venda('v1', deleted: true)]).recebido, 0);
    });
  });

  group('agrupamento', () {
    test('por dia, somando vendas, despesas e pagamentos', () {
      final seg = DateTime(2026, 11, 16, 9);
      final grupos = agruparTotais<DateTime>(
        vendas: [
          _venda('v1', data: seg),
          _venda('v2', data: _quarta),
        ],
        despesas: [
          _despesa(10, data: seg),
          _despesa(5, data: seg),
        ],
        pagamentos: [_pagamento(20, _quarta)],
        chaveVenda: (v) => chaveDoDia(v.data),
        chaveDespesa: (d) => chaveDoDia(d.data),
        chavePagamento: (p) => chaveDoDia(p.data),
      );
      expect(grupos.length, 2);
      expect(grupos[DateTime(2026, 11, 16)]!.despesas, 1500);
      expect(grupos[DateTime(2026, 11, 16)]!.vendas, 1);
      expect(grupos[DateTime(2026, 11, 18)]!.recebido, 10000 + 2000);
    });

    test('chave nula deixa o registro de fora', () {
      final grupos = agruparTotais<String>(
        vendas: [_venda('v1'), _venda('v2')],
        chaveVenda: (v) => v.id == 'v1' ? 'toledo' : null,
        chaveDespesa: (_) => null,
      );
      expect(grupos.keys, ['toledo']);
    });

    test('série diária traz um ponto por dia, com os vazios zerados', () {
      final periodo = Periodo.semana(_quarta);
      final serie = serieDiaria(
        periodo: periodo,
        vendas: [_venda('v1')],
        despesas: [_despesa(10)],
      );
      expect(serie.length, 7);
      expect(serie[2].dia, DateTime(2026, 11, 18));
      expect(serie[2].totais.faturamento, 10000);
      expect(serie[0].totais.vazio, isTrue);
    });
  });

  group('variação percentual', () {
    test('período anterior zerado não tem base: null', () {
      expect(variacaoPercentual(atual: 500, anterior: 0), isNull);
    });

    test('alta, queda e estabilidade', () {
      expect(variacaoPercentual(atual: 150, anterior: 100), 50);
      expect(variacaoPercentual(atual: 50, anterior: 100), -50);
      expect(variacaoPercentual(atual: 100, anterior: 100), 0);
    });

    test('anterior negativo: sair do prejuízo é variação positiva', () {
      expect(variacaoPercentual(atual: 0, anterior: -100), 100);
    });

    test('comparação sem movimento no anterior mostra null em tudo', () {
      final c = ComparacaoPeriodo(
        atual: calcularTotais(vendas: [_venda('v1')]),
        anterior: TotaisFinanceiros.zero,
      );
      expect(c.temBase, isFalse);
      expect(c.variacaoFaturamento, isNull);
      expect(c.variacaoDespesas, isNull);
      expect(c.variacaoLucroLiquido, isNull);
    });

    test('comparação com base calcula as três variações', () {
      final c = ComparacaoPeriodo(
        atual: calcularTotais(vendas: [_venda('v1'), _venda('v2')]),
        anterior: calcularTotais(
          vendas: [_venda('v3')],
          despesas: [_despesa(10)],
        ),
      );
      expect(c.variacaoFaturamento, 100);
      expect(c.variacaoDespesas, -100);
      expect(c.variacaoLucroLiquido, isNotNull);
    });
  });

  group('painel', () {
    final periodo = Periodo.semana(_quarta);
    final anteriorDia = DateTime(2026, 11, 10, 10);

    test('filtra cada registro pelo período e compara com o anterior', () {
      final p = montarPainel(
        periodo: periodo,
        vendas: [
          _venda('atual'),
          _venda('anterior', data: anteriorDia),
          _venda('fora', data: DateTime(2026, 10, 1)),
          _venda('depois', data: DateTime(2026, 11, 23)),
        ],
        despesas: [
          _despesa(10),
          _despesa(20, data: anteriorDia),
        ],
        pagamentos: [_pagamento(5, _quarta), _pagamento(7, anteriorDia)],
      );
      expect(p.totais.vendas, 1);
      expect(p.comparacao.anterior.vendas, 1);
      expect(p.totais.despesas, 1000);
      expect(p.comparacao.anterior.despesas, 2000);
      expect(p.totais.recebido, 10000 + 500);
      expect(p.recebidoCompleto, isTrue);
      expect(p.serie.length, 7);
    });

    test('sem pagamentos carregados, recebido fica incompleto', () {
      final p = montarPainel(periodo: periodo, vendas: [], despesas: []);
      expect(p.recebidoCompleto, isFalse);
      expect(p.totais.vazio, isTrue);
    });

    test('despesas por dia só traz os dias com despesa', () {
      final p = montarPainel(
        periodo: periodo,
        vendas: [],
        despesas: [_despesa(10), _despesa(5)],
      );
      expect(p.despesasPorDia.length, 1);
      expect(p.despesasPorDia.single.totais.despesas, 1500);
    });

    test('top produtos ordena por quantidade e limita a 5', () {
      final itens = [
        for (var i = 1; i <= 6; i++)
          _item(produto: 'p$i', nome: 'Produto $i', quantidade: i, preco: 10),
      ];
      final top = produtosMaisVendidos([_venda('v1', itens: itens)]);
      expect(top.length, 5);
      expect(top.first.nome, 'Produto 6');
      expect(top.first.quantidade, 6);
      expect(top.first.faturamento, 6000);
    });

    test('top produtos soma o mesmo produto de vendas diferentes e ignora canceladas', () {
      final top = produtosMaisVendidos([
        _venda('v1', itens: [_item(quantidade: 2)]),
        _venda('v2', itens: [_item(quantidade: 3)]),
        _venda('v3', itens: [_item(quantidade: 9)], deleted: true),
      ]);
      expect(top.single.quantidade, 5);
    });
  });
}
