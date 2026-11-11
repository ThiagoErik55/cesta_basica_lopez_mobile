import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/regra_bloqueio.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/status_pagamento.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/agenda_vendedor.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/controle_promissorias.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);
// "Hoje" dos testes e a data da agenda: sábado, 14/11/2026.
final _hoje = DateTime(2026, 11, 14, 9, 30);
final _data = DateTime(2026, 11, 14);
const _regra = RegraBloqueio();

RotaModel _rota(String id, String nome, {bool deleted = false}) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
  deleted: deleted,
);

ClienteModel _c(
  String id,
  String nome, {
  String? rotaId,
  bool deleted = false,
  bool bloqueado = false,
  double aberto = 0,
  DateTime? proximo,
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '52998224725',
  telefone: '(45) 99999-0000',
  endereco: 'Rua $id',
  rotaId: rotaId,
  bloqueado: bloqueado,
  valorEmAberto: aberto,
  proximoVencimento: proximo,
  updatedAt: _t,
  deleted: deleted,
);

ParcelaModel _p(
  String id,
  DateTime venc, {
  double valor = 100,
  bool pago = false,
  double pagoParcial = 0,
}) => ParcelaModel(
  id: id,
  vendaId: 'v',
  numero: 1,
  valor: valor,
  vencimento: venc,
  pago: pago,
  pagamentos: pagoParcial > 0
      ? [
          PagamentoModel(
            id: 'pg$id',
            valor: pagoParcial,
            data: _t,
            forma: FormaPagamento.pix,
          ),
        ]
      : const [],
  updatedAt: _t,
);

final _rotas = [_rota('a', 'Centro'), _rota('b', 'Norte')];

List<ItemAgenda> _agenda(
  List<ClienteModel> clientes, {
  String? rotaId,
  Map<String, List<ParcelaModel>>? parcelas = const {},
  DateTime? data,
  List<RotaModel>? rotas,
}) => montarAgenda(
  clientes: clientes,
  rotas: rotas ?? _rotas,
  data: data ?? _data,
  rotaId: rotaId,
  parcelasPendentesPorCliente: parcelas,
  regra: _regra,
  agora: _hoje,
);

ItemAgenda _um(
  ClienteModel c,
  Map<String, List<ParcelaModel>> parcelas, {
  DateTime? data,
}) => _agenda([c], parcelas: parcelas, data: data).single;

List<String> _nomes(Iterable<ItemAgenda> l) => [
  for (final i in l) i.cliente.nome,
];

void main() {
  group('datas', () {
    test('soData tira a hora', () {
      expect(
        soData(DateTime(2026, 11, 14, 23, 59, 59)),
        DateTime(2026, 11, 14),
      );
      expect(soData(DateTime(2026, 11, 14, 0, 0, 1)), DateTime(2026, 11, 14));
    });

    test('virada do dia: 23:59 e 00:00 são dias diferentes', () {
      expect(
        soData(DateTime(2026, 11, 14, 23, 59)),
        isNot(soData(DateTime(2026, 11, 15, 0, 0))),
      );
      expect(
        diasEntre(DateTime(2026, 11, 15, 0, 1), DateTime(2026, 11, 14, 23, 59)),
        1,
      );
    });

    test('data em UTC é convertida para o dia local do vendedor', () {
      final utc = DateTime.utc(2026, 11, 14, 2, 30);
      final local = utc.toLocal();
      expect(soData(utc), DateTime(local.year, local.month, local.day));
      // Mesmo instante, escrito em UTC ou em local, é o mesmo dia.
      expect(soData(utc), soData(local));
    });

    test('diasEntre atravessa mês, ano e horário de verão', () {
      expect(diasEntre(DateTime(2026, 11, 1), DateTime(2026, 10, 31)), 1);
      expect(diasEntre(DateTime(2027, 1, 1), DateTime(2026, 12, 31)), 1);
      expect(diasEntre(DateTime(2026, 11, 14), DateTime(2026, 11, 14)), 0);
      expect(diasEntre(DateTime(2026, 11, 13), DateTime(2026, 11, 14)), -1);
      expect(diasEntre(DateTime(2026, 3, 1), DateTime(2026, 2, 1)), 28);
    });

    test('rótulo da data com o dia da semana', () {
      expect(rotuloDaData(DateTime(2026, 11, 14, 8)), 'Sábado, 14/11/2026');
      expect(rotuloDaData(DateTime(2026, 11, 16)), 'Segunda, 16/11/2026');
    });
  });

  group('montarAgenda: quem entra', () {
    final clientes = [
      _c('1', 'Ana', rotaId: 'a'),
      _c('2', 'Beto', rotaId: 'b'),
      _c('3', 'Caio'),
      _c('4', 'Dora', rotaId: 'velha'),
      _c('5', 'Excluído', rotaId: 'a', deleted: true),
      _c('6', 'Bloqueado', rotaId: 'a', bloqueado: true),
    ];

    test('rota específica: só os dela, sem os sem rota', () {
      expect(_nomes(_agenda(clientes, rotaId: 'a')), ['Ana', 'Bloqueado']);
    });

    test(
      'todas as rotas: inclui sem rota e rota inexistente como sem rota',
      () {
        final itens = _agenda(clientes);
        expect(_nomes(itens), ['Ana', 'Beto', 'Caio', 'Dora', 'Bloqueado']);
        final porNome = {for (final i in itens) i.cliente.nome: i};
        expect(porNome['Caio']!.rotaId, isNull);
        expect(porNome['Dora']!.rotaId, isNull);
        expect(porNome['Ana']!.rotaNome, 'Centro');
      },
    );

    test('rota excluída conta como sem rota', () {
      final rotas = [_rota('a', 'Centro', deleted: true), _rota('b', 'Norte')];
      final itens = _agenda([_c('1', 'Ana', rotaId: 'a')], rotas: rotas);
      expect(itens.single.rotaId, isNull);
      expect(
        _agenda(
          [_c('1', 'Ana', rotaId: 'a')],
          rotas: rotas,
          rotaId: 'a',
        ),
        isEmpty,
      );
    });

    test('cliente excluído nunca aparece; bloqueado aparece', () {
      final itens = _agenda(clientes);
      expect(_nomes(itens), isNot(contains('Excluído')));
      expect(_nomes(itens), contains('Bloqueado'));
    });
  });

  group('montarAgenda: vencimentos na data', () {
    test('vencendo no dia exato (com hora diferente)', () {
      final c = _c('1', 'Ana', aberto: 100);
      final i = _um(c, {
        '1': [_p('p1', DateTime(2026, 11, 14, 18, 45))],
      });
      expect(i.vencendoNaData, isTrue);
      expect(i.vencida, isFalse);
      expect(i.diasVencida, 0);
      expect(i.aReceber, 100);
      expect(i.aCobrar, isTrue);
    });

    test('vencida: dias de atraso em relação à data escolhida', () {
      final i = _um(_c('1', 'Ana', aberto: 100), {
        '1': [_p('p1', DateTime(2026, 11, 11))],
      });
      expect(i.vencida, isTrue);
      expect(i.diasVencida, 3);
      expect(i.vencendoNaData, isFalse);
      expect(i.aReceber, 100);
    });

    test('a vencer depois da data não conta', () {
      final i = _um(_c('1', 'Ana', aberto: 100), {
        '1': [_p('p1', DateTime(2026, 11, 15))],
      });
      expect(i.aCobrar, isFalse);
      expect(i.aReceber, 0);
      expect(i.vencida, isFalse);
    });

    test('vencida e vencendo ao mesmo tempo: maior atraso e soma das duas', () {
      final i = _um(_c('1', 'Ana', aberto: 250), {
        '1': [
          _p('p1', DateTime(2026, 11, 4), valor: 50),
          _p('p2', DateTime(2026, 11, 10), valor: 100),
          _p('p3', DateTime(2026, 11, 14), valor: 100),
          _p('p4', DateTime(2026, 12, 14), valor: 999),
        ],
      });
      expect(i.diasVencida, 10);
      expect(i.vencendoNaData, isTrue);
      expect(i.aReceber, 250);
    });

    test('parcela paga ou excluída não conta; parcial conta o saldo', () {
      final i = _um(_c('1', 'Ana', aberto: 60), {
        '1': [
          _p('p1', DateTime(2026, 11, 10), pago: true),
          _p('p2', DateTime(2026, 11, 10), valor: 100, pagoParcial: 40),
        ],
      });
      expect(i.aReceber, 60);
      expect(i.diasVencida, 4);
    });

    test('mudar a data muda o destaque (a mesma parcela)', () {
      final c = _c('1', 'Ana', aberto: 100);
      final parcelas = {
        '1': [_p('p1', DateTime(2026, 11, 14))],
      };
      expect(_um(c, parcelas, data: DateTime(2026, 11, 13)).aCobrar, isFalse);
      expect(
        _um(c, parcelas, data: DateTime(2026, 11, 14)).vencendoNaData,
        isTrue,
      );
      final depois = _um(c, parcelas, data: DateTime(2026, 11, 17));
      expect(depois.diasVencida, 3);
      expect(depois.vencendoNaData, isFalse);
    });

    test('vencimento em UTC cai no dia local certo', () {
      final utc = DateTime.utc(2026, 11, 14, 12);
      final i = _um(_c('1', 'Ana', aberto: 100), {
        '1': [_p('p1', utc)],
      }, data: soData(utc));
      expect(i.vencendoNaData, isTrue);
    });

    test('saldoVencido: só as parcelas vencidas, sem a que vence na data', () {
      final i = _um(_c('1', 'Ana', aberto: 300), {
        '1': [
          _p('p1', DateTime(2026, 11, 10), valor: 100, pagoParcial: 30),
          _p('p2', DateTime(2026, 11, 14), valor: 100),
          _p('p3', DateTime(2026, 12, 14), valor: 100),
        ],
      });
      expect(i.saldoVencido, 70);
      expect(i.aReceber, 170);
    });

    test('saldoVencido sem as parcelas: valor em aberto, se já venceu', () {
      final vencido = _agenda([
        _c('1', 'Ana', aberto: 120, proximo: DateTime(2026, 11, 10)),
      ], parcelas: null).single;
      expect(vencido.saldoVencido, 120);
      final emDia = _agenda([
        _c('1', 'Ana', aberto: 120, proximo: DateTime(2026, 11, 20)),
      ], parcelas: null).single;
      expect(emDia.saldoVencido, 0);
    });

    test('cliente sem parcelas pendentes: nada a destacar', () {
      final i = _um(_c('1', 'Ana'), {});
      expect(i.aCobrar, isFalse);
      expect(i.aReceber, 0);
      expect(i.valoresPorParcela, isTrue);
    });
  });

  group('montarAgenda: sem as parcelas (estimado pelo resumo)', () {
    test('usa proximoVencimento e valorEmAberto, sem calcular o a receber', () {
      final vencendo = _agenda([
        _c('1', 'Ana', aberto: 100, proximo: DateTime(2026, 11, 14)),
      ], parcelas: null).single;
      expect(vencendo.vencendoNaData, isTrue);
      expect(vencendo.valoresPorParcela, isFalse);
      expect(vencendo.aReceber, 0);

      final vencida = _agenda([
        _c('1', 'Ana', aberto: 100, proximo: DateTime(2026, 11, 10)),
      ], parcelas: null).single;
      expect(vencida.diasVencida, 4);
    });

    test('sem débito, o proximoVencimento antigo não conta', () {
      final i = _agenda([
        _c('1', 'Ana', aberto: 0, proximo: DateTime(2026, 11, 1)),
      ], parcelas: null).single;
      expect(i.aCobrar, isFalse);
    });
  });

  group('situação (status de pagamento)', () {
    test('em dia, em atraso e bloqueado pela regra automática', () {
      final emDia = _um(_c('1', 'Ana'), {});
      expect(emDia.situacao.status, StatusPagamento.emDia);

      // O status "em atraso" vem do resumo do cliente (proximoVencimento),
      // como no resto do app.
      final atraso = _um(
        _c('1', 'Ana', aberto: 100, proximo: DateTime(2026, 11, 10)),
        {
          '1': [_p('p1', DateTime(2026, 11, 10))], // 4 dias
        },
      );
      expect(atraso.situacao.status, StatusPagamento.emAtraso);

      final bloqueado = _um(_c('1', 'Ana', aberto: 100), {
        '1': [_p('p1', DateTime(2026, 10, 20))], // 25 dias ≥ 15
      });
      expect(bloqueado.situacao.status, StatusPagamento.bloqueado);
      expect(bloqueado.situacao.motivo, 'Atraso de 25 dias');
      expect(bloqueado.bloqueado, isTrue);
    });

    test('bloqueio manual', () {
      final i = _um(_c('1', 'Ana', bloqueado: true), {});
      expect(i.situacao.status, StatusPagamento.bloqueado);
      expect(i.situacao.motivo, 'Bloqueio manual');
    });
  });

  group('resumirAgenda', () {
    test('totais e valor a receber', () {
      final itens = _agenda(
        [
          _c('1', 'Ana', aberto: 100),
          _c('2', 'Beto', aberto: 200),
          _c('3', 'Caio'),
        ],
        parcelas: {
          '1': [_p('p1', DateTime(2026, 11, 14), valor: 100)],
          '2': [
            _p('p2', DateTime(2026, 11, 10), valor: 150),
            _p('p3', DateTime(2026, 12, 10), valor: 50),
          ],
        },
      );
      final r = resumirAgenda(itens);
      expect(r.totalClientes, 3);
      expect(r.vencendoNaData, 1);
      expect(r.emAtraso, 1);
      expect(r.aReceber, 250);
      expect(r.valoresExatos, isTrue);
    });

    test('agenda vazia', () {
      final r = resumirAgenda(const []);
      expect(r.totalClientes, 0);
      expect(r.aReceber, 0);
      expect(r.valoresExatos, isTrue);
    });

    test('sem parcelas, o a receber não é exato', () {
      final itens = _agenda([_c('1', 'Ana')], parcelas: null);
      expect(resumirAgenda(itens).valoresExatos, isFalse);
    });

    test('soma sem erro de ponto flutuante', () {
      final itens = _agenda(
        [_c('1', 'Ana', aberto: 1), _c('2', 'Beto', aberto: 1)],
        parcelas: {
          '1': [_p('p1', DateTime(2026, 11, 14), valor: 0.1)],
          '2': [_p('p2', DateTime(2026, 11, 14), valor: 0.2)],
        },
      );
      expect(resumirAgenda(itens).aReceber, 0.3);
    });
  });

  group('filtrar e buscar', () {
    late List<ItemAgenda> itens;
    setUp(() {
      itens = _agenda(
        [
          _c('1', 'Ângela', aberto: 100),
          _c('2', 'Beto', aberto: 100),
          _c('3', 'Caio', bloqueado: true),
          _c('4', 'Dora'),
        ],
        parcelas: {
          '1': [_p('p1', DateTime(2026, 11, 14))], // vencendo
          '2': [_p('p2', DateTime(2026, 11, 10))], // vencida
        },
      );
    });

    test('todos', () {
      expect(filtrarAgenda(itens), hasLength(4));
    });

    test('a cobrar: vencendo ou vencida', () {
      expect(_nomes(filtrarAgenda(itens, filtro: FiltroAgenda.aCobrar)), [
        'Ângela',
        'Beto',
      ]);
    });

    test('em atraso: só vencida na data', () {
      expect(_nomes(filtrarAgenda(itens, filtro: FiltroAgenda.emAtraso)), [
        'Beto',
      ]);
    });

    test('bloqueados', () {
      expect(_nomes(filtrarAgenda(itens, filtro: FiltroAgenda.bloqueados)), [
        'Caio',
      ]);
    });

    test('busca por nome sem acento e sem maiúsculas', () {
      expect(_nomes(filtrarAgenda(itens, termo: 'angela')), ['Ângela']);
      expect(_nomes(filtrarAgenda(itens, termo: 'BET')), ['Beto']);
      expect(filtrarAgenda(itens, termo: 'zzz'), isEmpty);
    });

    test('busca combina com o filtro', () {
      expect(
        filtrarAgenda(itens, filtro: FiltroAgenda.aCobrar, termo: 'dora'),
        isEmpty,
      );
      expect(
        _nomes(filtrarAgenda(itens, filtro: FiltroAgenda.aCobrar, termo: 'be')),
        ['Beto'],
      );
    });
  });

  group('ordenarAgenda', () {
    test(
      'vencida (mais atraso primeiro), depois vencendo, depois por nome',
      () {
        final itens = _agenda(
          [
            _c('1', 'Zeca', aberto: 100), // vencendo
            _c('2', 'Ana'), // nada
            _c('3', 'Beto', aberto: 100), // vencida 2 dias
            _c('4', 'Caio', aberto: 100), // vencida 9 dias
            _c('5', 'Bia'), // nada
            _c('6', 'Alice', aberto: 100), // vencendo
          ],
          parcelas: {
            '1': [_p('a', DateTime(2026, 11, 14))],
            '3': [_p('b', DateTime(2026, 11, 12))],
            '4': [_p('c', DateTime(2026, 11, 5))],
            '6': [_p('d', DateTime(2026, 11, 14))],
          },
        );
        expect(_nomes(ordenarAgenda(itens)), [
          'Caio',
          'Beto',
          'Alice',
          'Zeca',
          'Ana',
          'Bia',
        ]);
      },
    );

    test('mesmo atraso desempata por nome', () {
      final itens = _agenda(
        [_c('1', 'Zeca', aberto: 1), _c('2', 'Ana', aberto: 1)],
        parcelas: {
          '1': [_p('a', DateTime(2026, 11, 10))],
          '2': [_p('b', DateTime(2026, 11, 10))],
        },
      );
      expect(_nomes(ordenarAgenda(itens)), ['Ana', 'Zeca']);
    });

    test('não altera a lista original', () {
      final itens = _agenda([_c('1', 'Zeca'), _c('2', 'Ana')]);
      ordenarAgenda(itens);
      expect(_nomes(itens), ['Zeca', 'Ana']);
    });
  });

  group('agruparAgendaPorRota', () {
    test('um grupo por rota em ordem alfabética e "Sem rota" por último', () {
      final itens = _agenda([
        _c('1', 'Ana', rotaId: 'b'),
        _c('2', 'Beto'),
        _c('3', 'Caio', rotaId: 'a'),
        _c('4', 'Dora', rotaId: 'a'),
      ]);
      final grupos = agruparAgendaPorRota(itens);
      expect(
        [for (final g in grupos) g.titulo],
        ['Centro', 'Norte', 'Sem rota'],
      );
      expect(_nomes(grupos[0].itens), ['Caio', 'Dora']);
      expect(grupos[2].rotaId, isNull);
      expect(_nomes(grupos[2].itens), ['Beto']);
    });

    test('dentro do grupo vale a ordem de prioridade', () {
      final itens = _agenda(
        [_c('1', 'Ana', rotaId: 'a'), _c('2', 'Zeca', rotaId: 'a', aberto: 10)],
        parcelas: {
          '2': [_p('p', DateTime(2026, 11, 10))],
        },
      );
      expect(_nomes(agruparAgendaPorRota(itens).single.itens), ['Zeca', 'Ana']);
    });

    test('sem itens, sem grupos', () {
      expect(agruparAgendaPorRota(const []), isEmpty);
    });
  });

  group('destaques', () {
    ItemAgenda item({required int dias, required bool vence}) => ItemAgenda(
      cliente: _c('1', 'Ana'),
      rotaId: null,
      rotaNome: null,
      situacao: _um(_c('1', 'Ana'), {}).situacao,
      vencendoNaData: vence,
      diasVencida: dias,
      aReceber: 0,
      valoresPorParcela: true,
    );

    test('textos', () {
      expect(destaquesDaAgenda(item(dias: 0, vence: false)), isEmpty);
      expect(destaquesDaAgenda(item(dias: 0, vence: true)), [
        'Vence nesta data',
      ]);
      expect(destaquesDaAgenda(item(dias: 1, vence: false)), [
        'Vencida há 1 dia',
      ]);
      expect(destaquesDaAgenda(item(dias: 5, vence: true)), [
        'Vencida há 5 dias',
        'Vence nesta data',
      ]);
    });
  });

  group('parcelasPendentesPorCliente', () {
    VendaModel venda(String id, String clienteId) => VendaModel(
      id: id,
      clienteId: clienteId,
      clienteNome: clienteId,
      vendedorUid: 'u',
      numeroNota: 1,
      data: _t,
      itens: const [],
      valorTotal: 200,
      tipo: TipoVenda.parcelado,
      updatedAt: _t,
    );

    test('agrupa as pendentes de todas as vendas do cliente', () {
      final itens = [
        ItemPromissoria.de(venda('v1', 'c1'), [
          _p('a', DateTime(2026, 11, 14)),
          _p('b', DateTime(2026, 12, 14), pago: true),
        ]),
        ItemPromissoria.de(venda('v2', 'c1'), [
          _p('c', DateTime(2026, 11, 20)),
        ]),
        ItemPromissoria.de(venda('v3', 'c2'), [
          _p('d', DateTime(2026, 11, 1), pago: true),
        ]),
      ];
      final mapa = parcelasPendentesPorCliente(itens);
      expect(mapa['c1']!.map((p) => p.id), ['a', 'c']);
      expect(mapa.containsKey('c2'), isFalse);
    });
  });
}
