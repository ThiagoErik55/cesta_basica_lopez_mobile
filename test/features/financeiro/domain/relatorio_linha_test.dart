import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/agregacao_financeira.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/relatorio_linha.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Semana de 16/11/2026 (segunda) a 22/11; a anterior é 09/11 a 15/11.
final _quarta = DateTime(2026, 11, 18, 10);
final _quartaAnterior = DateTime(2026, 11, 11, 10);
final _semana = Periodo.semana(_quarta);

RotaModel _rota(String id, LinhaAtendimento linha, {bool deleted = false}) =>
    RotaModel(
      id: id,
      codigo: id,
      nome: 'Rota $id',
      linhaAtendimento: linha,
      updatedAt: _quarta,
      deleted: deleted,
    );

ClienteModel _cliente(String id, {String? rotaId, bool deleted = false}) =>
    ClienteModel(
      id: id,
      codigo: id,
      nome: 'Cliente $id',
      cpf: '12345678909',
      telefone: '',
      endereco: '',
      rotaId: rotaId,
      updatedAt: _quarta,
      deleted: deleted,
    );

VendaModel _venda(
  String id,
  String clienteId, {
  DateTime? data,
  double preco = 100,
  double custo = 60,
  int quantidade = 1,
  TipoVenda tipo = TipoVenda.aVista,
  List<TrocaItem> trocas = const [],
  bool deleted = false,
}) => VendaModel(
  id: id,
  clienteId: clienteId,
  clienteNome: 'Cliente $clienteId',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: data ?? _quarta,
  itens: [
    ItemVenda(
      id: 'i$id',
      produtoId: 'p1',
      nome: 'Cesta',
      quantidade: quantidade,
      precoUnitario: preco,
      custoUnitario: custo,
    ),
  ],
  trocas: trocas,
  valorTotal: preco * quantidade,
  tipo: tipo,
  updatedAt: _quarta,
  deleted: deleted,
);

DespesaModel _despesa(double valor, {DateTime? data}) => DespesaModel(
  id: 'd$valor',
  vendedorUid: 'u1',
  descricao: 'Combustível',
  valor: valor,
  data: data ?? _quarta,
  updatedAt: _quarta,
);

PagamentoDeCliente _pagamento(String clienteId, double valor, DateTime data) =>
    PagamentoDeCliente(
      clienteId: clienteId,
      pagamento: PagamentoModel(
        id: 'pg$clienteId$valor',
        valor: valor,
        data: data,
        forma: FormaPagamento.pix,
      ),
    );

/// c1 → Toledo, c2 → Regional; c3 sem rota.
final _grupos = grupoDosClientes(
  [_cliente('c1', rotaId: 'rT'), _cliente('c2', rotaId: 'rR'), _cliente('c3')],
  [
    _rota('rT', LinhaAtendimento.toledo),
    _rota('rR', LinhaAtendimento.regional),
  ],
);

LinhaRelatorio _linha(RelatorioSemanal r, GrupoLinha g) =>
    r.linhas.firstWhere((l) => l.grupo == g);

void main() {
  group('grupoDosClientes (linha pela rota atual do cliente)', () {
    final rotas = [
      _rota('rT', LinhaAtendimento.toledo),
      _rota('rR', LinhaAtendimento.regional),
      _rota('rX', LinhaAtendimento.toledo, deleted: true),
    ];

    test('rota com linha define o grupo', () {
      final g = grupoDosClientes([
        _cliente('a', rotaId: 'rT'),
        _cliente('b', rotaId: 'rR'),
      ], rotas);
      expect(g['a'], GrupoLinha.toledo);
      expect(g['b'], GrupoLinha.regional);
    });

    test('cliente sem rota (null ou vazio) fica em sem linha', () {
      final g = grupoDosClientes([
        _cliente('a'),
        _cliente('b', rotaId: ''),
      ], rotas);
      expect(g['a'], GrupoLinha.semLinha);
      expect(g['b'], GrupoLinha.semLinha);
    });

    test('rota excluída, inexistente ou texto livre: sem linha', () {
      final g = grupoDosClientes([
        _cliente('a', rotaId: 'rX'),
        _cliente('b', rotaId: 'nao-existe'),
        _cliente('c', rotaId: 'Rota do Centro'),
      ], rotas);
      expect(g.values, everyElement(GrupoLinha.semLinha));
    });

    test('cliente excluído não entra; venda dele cai em sem linha', () {
      final g = grupoDosClientes([
        _cliente('a', rotaId: 'rT', deleted: true),
      ], rotas);
      expect(g.containsKey('a'), isFalse);
      expect(grupoDoCliente('a', g), GrupoLinha.semLinha);
    });

    test('mudar a rota do cliente move todas as vendas dele de linha', () {
      final vendas = [_venda('v1', 'a')];
      RelatorioSemanal relatorio(String rotaId) => montarRelatorioSemanal(
        semana: _semana,
        vendas: vendas,
        despesas: const [],
        grupos: grupoDosClientes([_cliente('a', rotaId: rotaId)], rotas),
      );
      expect(_linha(relatorio('rT'), GrupoLinha.toledo).totais.vendas, 1);
      expect(_linha(relatorio('rR'), GrupoLinha.regional).totais.vendas, 1);
      expect(_linha(relatorio('rR'), GrupoLinha.toledo).totais.vendas, 0);
    });
  });

  group('montarRelatorioSemanal', () {
    test('agrupa por linha e ordena por faturamento decrescente', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', preco: 100),
          _venda('v2', 'c2', preco: 300),
          _venda('v3', 'c2', preco: 50),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      expect(r.linhas.map((l) => l.grupo), [
        GrupoLinha.regional,
        GrupoLinha.toledo,
      ]);
      expect(r.linhas.first.totais.faturamento, 35000);
      expect(r.linhas.first.totais.vendas, 2);
      expect(r.linhas.last.totais.faturamento, 10000);
    });

    test('Toledo e Regional aparecem zeradas; sem linha só com movimento', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: const [],
        despesas: const [],
        grupos: _grupos,
      );
      expect(r.linhas.map((l) => l.grupo), [
        GrupoLinha.toledo,
        GrupoLinha.regional,
      ]);
      expect(r.vazio, isTrue);
      expect(r.linhas.every((l) => l.vazia), isTrue);
    });

    test('venda de cliente sem rota aparece em "Sem linha"', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [_venda('v1', 'c3', preco: 80)],
        despesas: const [],
        grupos: _grupos,
      );
      expect(_linha(r, GrupoLinha.semLinha).totais.faturamento, 8000);
      expect(_linha(r, GrupoLinha.semLinha).rotulo, 'Sem linha');
    });

    test('margem e ticket com 0 vendas são zero, nunca NaN', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: const [],
        despesas: const [],
        grupos: _grupos,
      );
      final l = _linha(r, GrupoLinha.toledo);
      expect(l.margem, 0);
      expect(l.margem.isNaN, isFalse);
      expect(l.totais.ticketMedio, 0);
      expect(l.participacaoDecimos, 0);
    });

    test('margem, ticket médio e lucro bruto da linha', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', preco: 100, custo: 60),
          _venda('v2', 'c1', preco: 200, custo: 100),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      final l = _linha(r, GrupoLinha.toledo);
      expect(l.totais.lucroBruto, 14000);
      expect(l.margem, closeTo(46.666, 0.01));
      expect(l.totais.ticketMedio, 15000);
    });

    test('venda com troca entra no faturamento da linha', () {
      final troca = TrocaItem(
        id: 't',
        itemOriginalId: 'i',
        produtoNovoId: 'p2',
        produtoNovoNome: 'Outro',
        quantidade: 1,
        diferencaValor: 15,
        data: _quarta,
      );
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', trocas: [troca]),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      final l = _linha(r, GrupoLinha.toledo);
      expect(l.totais.faturamento, 11500);
      expect(l.totais.custo, 6000);
      expect(l.totais.lucroBruto, 5500);
    });

    test('venda cancelada não conta em linha nenhuma', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1'),
          _venda('v2', 'c1', preco: 999, deleted: true),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      expect(_linha(r, GrupoLinha.toledo).totais.vendas, 1);
      expect(_linha(r, GrupoLinha.toledo).vendas.length, 1);
      expect(r.total.faturamento, 10000);
    });

    test('só entram vendas da semana; a anterior serve à comparação', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', preco: 100),
          _venda('v2', 'c1', preco: 80, data: _quartaAnterior),
          _venda('v3', 'c1', preco: 500, data: DateTime(2026, 11, 23)),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      final l = _linha(r, GrupoLinha.toledo);
      expect(l.totais.faturamento, 10000);
      expect(l.anterior.faturamento, 8000);
      expect(l.variacaoFaturamento, closeTo(25, 0.001));
    });

    test('domingo 23:59 entra na semana; segunda 00:00 não', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', data: DateTime(2026, 11, 22, 23, 59)),
          _venda('v2', 'c1', data: DateTime(2026, 11, 23)),
          _venda('v3', 'c1', data: DateTime(2026, 11, 16)),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      expect(_linha(r, GrupoLinha.toledo).totais.vendas, 2);
    });

    test('variação é "—" (null) quando a semana anterior não vendeu', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1'),
          _venda('v2', 'c2', data: _quartaAnterior),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      expect(_linha(r, GrupoLinha.toledo).variacaoFaturamento, isNull);
      expect(_linha(r, GrupoLinha.toledo).variacaoLucroBruto, isNull);
      expect(_linha(r, GrupoLinha.regional).variacaoFaturamento, isNotNull);
    });

    test('variação do lucro bruto por linha', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', preco: 100, custo: 50),
          _venda('v2', 'c1', preco: 100, custo: 80, data: _quartaAnterior),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      // lucro 50 contra 20: +150%.
      expect(
        _linha(r, GrupoLinha.toledo).variacaoLucroBruto,
        closeTo(150, 0.001),
      );
    });

    test('semana sem movimento: tudo zerado e sem variação', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: const [],
        despesas: const [],
        grupos: _grupos,
      );
      expect(r.vazio, isTrue);
      expect(r.total.faturamento, 0);
      expect(r.lucroLiquido, 0);
      expect(r.variacaoFaturamento, isNull);
    });
  });

  group('participação', () {
    test('as linhas somam exatamente 100,0%', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', preco: 100),
          _venda('v2', 'c2', preco: 100),
          _venda('v3', 'c3', preco: 100),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      // 33,3 + 33,3 + 33,3 = 99,9: o maior resto leva o décimo que falta.
      expect(r.linhas.fold<int>(0, (s, l) => s + l.participacaoDecimos), 1000);
    });

    test('repartirParticipacao soma 1000 em vários casos', () {
      for (final valores in [
        [1, 1, 1],
        [10000, 35000],
        [7, 13, 29, 1],
        [1, 0, 0],
        [333, 333, 334],
      ]) {
        expect(
          repartirParticipacao(valores).fold<int>(0, (s, v) => s + v),
          1000,
          reason: '$valores',
        );
      }
    });

    test('sem faturamento, participação zero em todas', () {
      expect(repartirParticipacao([0, 0]), [0, 0]);
      expect(repartirParticipacao([]), isEmpty);
    });

    test('proporção simples', () {
      expect(repartirParticipacao([25, 75]), [250, 750]);
    });
  });

  group('total e despesas gerais', () {
    final vendas = [
      _venda('v1', 'c1', preco: 100, custo: 60),
      _venda('v2', 'c2', preco: 250, custo: 100),
      _venda('v3', 'c3', preco: 40, custo: 10),
      _venda('v4', 'c1', preco: 10, custo: 5, data: _quartaAnterior),
    ];
    final despesas = [
      _despesa(30),
      _despesa(12.5),
      _despesa(99, data: _quartaAnterior),
    ];

    test('despesas ficam fora das linhas e só entram no total', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: vendas,
        despesas: despesas,
        grupos: _grupos,
      );
      for (final l in r.linhas) {
        expect(l.totais.despesas, 0);
      }
      expect(r.despesasGerais, 4250);
      expect(r.quantidadeDespesas, 2);
    });

    test('lucro líquido = Σ lucro bruto das linhas − despesas', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: vendas,
        despesas: despesas,
        grupos: _grupos,
      );
      final somaLucro = r.linhas.fold<int>(
        0,
        (s, l) => s + l.totais.lucroBruto,
      );
      expect(somaLucro, 22000); // 4.000 + 15.000 + 3.000
      expect(r.lucroLiquido, somaLucro - 4250);
    });

    test('total bate com o painel da KAN-52 para a mesma semana', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: vendas,
        despesas: despesas,
        grupos: _grupos,
        pagamentos: [_pagamento('c1', 20, _quarta)],
      );
      final painel = montarPainel(
        periodo: _semana,
        vendas: vendas,
        despesas: despesas,
        pagamentos: [_pagamento('c1', 20, _quarta).pagamento],
      );
      expect(r.total.faturamento, painel.totais.faturamento);
      expect(r.total.custo, painel.totais.custo);
      expect(r.total.lucroBruto, painel.totais.lucroBruto);
      expect(r.total.despesas, painel.totais.despesas);
      expect(r.total.lucroLiquido, painel.totais.lucroLiquido);
      expect(r.total.vendas, painel.totais.vendas);
      expect(r.total.recebido, painel.totais.recebido);
      expect(
        r.totalAnterior.faturamento,
        painel.comparacao.anterior.faturamento,
      );
    });

    test('total inclui "sem linha" mesmo sem linha exibida pelo nome', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [_venda('v1', 'cliente-apagado', preco: 70)],
        despesas: const [],
        grupos: _grupos,
      );
      expect(_linha(r, GrupoLinha.semLinha).totais.faturamento, 7000);
      expect(r.total.faturamento, 7000);
    });
  });

  group('recebido por linha', () {
    test(
      'à vista conta na linha do cliente e parcelada só pelos pagamentos',
      () {
        final r = montarRelatorioSemanal(
          semana: _semana,
          vendas: [
            _venda('v1', 'c1', preco: 100),
            _venda('v2', 'c2', preco: 200, tipo: TipoVenda.parcelado),
          ],
          despesas: const [],
          grupos: _grupos,
          pagamentos: [
            _pagamento('c2', 50, _quarta),
            _pagamento('c2', 70, _quartaAnterior),
          ],
        );
        expect(_linha(r, GrupoLinha.toledo).totais.recebido, 10000);
        expect(_linha(r, GrupoLinha.regional).totais.recebido, 5000);
        expect(r.total.recebido, 15000);
        expect(r.recebidoCompleto, isTrue);
      },
    );

    test('sem os pagamentos carregados, recebidoCompleto é falso', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [_venda('v1', 'c1')],
        despesas: const [],
        grupos: _grupos,
      );
      expect(r.recebidoCompleto, isFalse);
      expect(r.total.recebido, 10000);
    });

    test('pagamento de cliente sem linha aparece em "Sem linha"', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: const [],
        despesas: const [],
        grupos: _grupos,
        pagamentos: [_pagamento('c3', 40, _quarta)],
      );
      expect(_linha(r, GrupoLinha.semLinha).totais.recebido, 4000);
    });
  });

  group('detalhe da linha', () {
    test('clientes que mais compraram: por valor, só nome, limite 5', () {
      final vendas = [
        for (var i = 1; i <= 7; i++) _venda('v$i', 'c$i', preco: i * 10.0),
        _venda('extra', 'c1', preco: 5),
      ];
      final top = clientesQueMaisCompraram(vendas);
      expect(top.length, 5);
      expect(top.first.clienteId, 'c7');
      expect(top.first.nome, 'Cliente c7');
      expect(top.map((c) => c.valor), [7000, 6000, 5000, 4000, 3000]);
    });

    test('cliente agrega vendas e ignora as canceladas', () {
      final top = clientesQueMaisCompraram([
        _venda('v1', 'c1', preco: 100),
        _venda('v2', 'c1', preco: 50),
        _venda('v3', 'c1', preco: 999, deleted: true),
      ]);
      expect(top.single.vendas, 2);
      expect(top.single.valor, 15000);
    });

    test('detalhe: vendas por dia da semana e produtos da linha', () {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: [
          _venda('v1', 'c1', data: DateTime(2026, 11, 16, 9)),
          _venda('v2', 'c1', data: DateTime(2026, 11, 16, 15)),
          _venda('v3', 'c2', data: DateTime(2026, 11, 18)),
        ],
        despesas: const [],
        grupos: _grupos,
      );
      final d = detalharLinha(_linha(r, GrupoLinha.toledo), _semana);
      expect(d.vendasPorDia.length, 7);
      expect(d.vendasPorDia.first.totais.vendas, 2);
      expect(d.vendasPorDia.fold<int>(0, (s, p) => s + p.totais.vendas), 2);
      expect(d.topProdutos.single.quantidade, 2);
      expect(d.topClientes.single.clienteId, 'c1');
    });
  });
}
