import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/bloqueio_cliente.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/regra_bloqueio.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/status_pagamento.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/agenda_vendedor.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/recomendacao_visita.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/regra_recomendacao.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);
// Sábado, 14/11/2026.
final _hoje = DateTime(2026, 11, 14, 9, 30);
final _data = DateTime(2026, 11, 14);
const _regra = RegraRecomendacao();

/// Última compra "recente": 4 dias antes da data.
final _recente = DateTime(2026, 11, 10);

ItemAgenda _item(
  String nome, {
  ScoreCliente score = ScoreCliente.b,
  DateTime? ultima,
  bool semCompra = false,
  int vencida = 0,
  double saldoVencido = 0,
  bool vence = false,
  bool bloqueado = false,
  String? rotaId,
}) {
  final cliente = ClienteModel(
    id: 'c-$nome',
    codigo: 'C-$nome',
    nome: nome,
    cpf: '52998224725',
    telefone: '',
    endereco: '',
    rotaId: rotaId,
    score: score,
    ultimaCompra: semCompra ? null : (ultima ?? _recente),
    updatedAt: _t,
  );
  return ItemAgenda(
    cliente: cliente,
    rotaId: rotaId,
    rotaNome: rotaId,
    situacao: bloqueado
        ? const SituacaoCliente(
            status: StatusPagamento.bloqueado,
            motivo: 'Bloqueio manual',
          )
        : const SituacaoCliente(status: StatusPagamento.emDia),
    vencendoNaData: vence,
    diasVencida: vencida,
    aReceber: saldoVencido,
    saldoVencido: saldoVencido,
    valoresPorParcela: true,
  );
}

Recomendacao? _pontuar(ItemAgenda i, {RegraRecomendacao regra = _regra}) =>
    pontuarVisita(i, regra: regra, data: _data, hoje: _hoje);

List<String> _nomes(Iterable<Recomendacao> l) => [
  for (final r in l) r.item.cliente.nome,
];

void main() {
  group('regra padrão', () {
    test('os padrões estão nas constantes nomeadas', () {
      const r = RegraRecomendacao();
      expect(r.quantidade, padraoQuantidadeRecomendados);
      expect(r.quantidade, 5);
      expect(r.pesoAtrasoBase, padraoPesoAtrasoBase);
      expect(r.diasInatividade, padraoDiasInatividade);
      expect(r.diasInatividade, 30);
      expect(r.pesoNuncaComprou, padraoPesoNuncaComprou);
      expect(regraRecomendacaoPadrao.quantidade, 5);
    });

    test(
      'score fora do mapa usa multiplicador 1; copyWith troca só o pedido',
      () {
        final r = const RegraRecomendacao().copyWith(
          multiplicadorCobranca: const {},
          quantidade: 3,
        );
        expect(r.cobrancaDo(ScoreCliente.d), 1);
        expect(r.reativacaoDo(ScoreCliente.a), 1.3);
        expect(r.quantidade, 3);
        expect(r.pesoVenceNaData, padraoPesoVenceNaData);
      },
    );
  });

  group('fator: atraso', () {
    test('base + dias + saldo vencido (score B, multiplicador 1)', () {
      final r = _pontuar(_item('A', vencida: 10, saldoVencido: 200))!;
      // 40 + 10×1 + (200/100)×2
      expect(r.pontos, closeTo(54, 1e-9));
      expect(r.motivo, MotivoVisita.cobrancaEmAtraso);
    });

    test('mais dias de atraso pontuam mais', () {
      final a = _pontuar(_item('A', vencida: 5))!;
      final b = _pontuar(_item('B', vencida: 20))!;
      expect(b.pontos, greaterThan(a.pontos));
    });

    test('maior saldo vencido pontua mais', () {
      final a = _pontuar(_item('A', vencida: 5, saldoVencido: 100))!;
      final b = _pontuar(_item('B', vencida: 5, saldoVencido: 800))!;
      expect(b.pontos, greaterThan(a.pontos));
    });

    test('os dias têm teto (60)', () {
      final a = _pontuar(_item('A', vencida: 60))!;
      final b = _pontuar(_item('B', vencida: 400))!;
      expect(b.pontos, a.pontos);
    });

    test('o saldo tem teto (R\$ 1.500)', () {
      final a = _pontuar(_item('A', vencida: 5, saldoVencido: 1500))!;
      final b = _pontuar(_item('B', vencida: 5, saldoVencido: 90000))!;
      expect(b.pontos, a.pontos);
      // 40 + 5 + 15×2
      expect(a.pontos, closeTo(75, 1e-9));
    });

    test('o score multiplica a cobrança: D > C > B = A', () {
      double p(ScoreCliente s) =>
          _pontuar(_item('X', score: s, vencida: 10))!.pontos;
      expect(p(ScoreCliente.d), closeTo(50 * 1.5, 1e-9));
      expect(p(ScoreCliente.c), closeTo(50 * 1.25, 1e-9));
      expect(p(ScoreCliente.b), closeTo(50, 1e-9));
      expect(p(ScoreCliente.a), closeTo(50, 1e-9));
    });
  });

  group('fator: vence na data', () {
    test('peso fixo, com multiplicador de cobrança', () {
      final b = _pontuar(_item('A', vence: true))!;
      expect(b.pontos, closeTo(35, 1e-9));
      expect(b.motivo, MotivoVisita.venceNaData);
      final d = _pontuar(_item('B', score: ScoreCliente.d, vence: true))!;
      expect(d.pontos, closeTo(35 * 1.5, 1e-9));
    });
  });

  group('fator: inatividade', () {
    test('abaixo do limite (29 dias) não pontua', () {
      expect(_pontuar(_item('A', ultima: DateTime(2026, 10, 16))), isNull);
    });

    test('exatamente no limite (30 dias) entra com o peso base', () {
      final r = _pontuar(_item('A', ultima: DateTime(2026, 10, 15)))!;
      // 10 × 1,15 (score B)
      expect(r.pontos, closeTo(11.5, 1e-9));
      expect(r.motivo, MotivoVisita.reativacao);
      expect(r.textoMotivo, 'Sem comprar há 30 dias');
    });

    test('cresce com os dias além do limite', () {
      final a = _pontuar(_item('A', ultima: DateTime(2026, 10, 1)))!; // 44
      final b = _pontuar(_item('B', ultima: DateTime(2026, 8, 1)))!; // 105
      expect(b.pontos, greaterThan(a.pontos));
      expect(a.textoMotivo, 'Sem comprar há 44 dias');
    });

    test('tem teto (150 dias)', () {
      final a = _pontuar(
        _item('A', score: ScoreCliente.a, ultima: DateTime(2026, 6, 17)),
      )!; // 150 dias
      final b = _pontuar(
        _item('B', score: ScoreCliente.a, ultima: DateTime(2024, 1, 1)),
      )!;
      expect(b.pontos, a.pontos);
      // (10 + 120×0,1) × 1,3
      expect(a.pontos, closeTo(22 * 1.3, 1e-9));
    });

    test('o score favorece A/B na reativação: A > B > C > D', () {
      double p(ScoreCliente s) =>
          _pontuar(_item('X', score: s, ultima: DateTime(2026, 9, 1)))!.pontos;
      expect(p(ScoreCliente.a), greaterThan(p(ScoreCliente.b)));
      expect(p(ScoreCliente.b), greaterThan(p(ScoreCliente.c)));
      expect(p(ScoreCliente.c), greaterThan(p(ScoreCliente.d)));
    });
  });

  group('fator: nunca comprou', () {
    test('peso baixo e fixo, igual para qualquer score', () {
      final a = _pontuar(_item('A', semCompra: true, score: ScoreCliente.a))!;
      final d = _pontuar(_item('D', semCompra: true, score: ScoreCliente.d))!;
      expect(a.pontos, 12);
      expect(d.pontos, 12);
      expect(a.motivo, MotivoVisita.clienteNovo);
      expect(a.textoMotivo, 'Ainda não comprou');
    });
  });

  group('pontuação zero', () {
    test('quitado, sem atraso e que comprou recentemente: não aparece', () {
      expect(_pontuar(_item('A')), isNull);
    });

    test('vencimento futuro e compra recente: não aparece', () {
      // Nem vencida nem vencendo na data.
      expect(_pontuar(_item('A', ultima: DateTime(2026, 11, 13))), isNull);
    });
  });

  group('combinação de fatores', () {
    test('atraso + vence + inatividade somam', () {
      final r = _pontuar(
        _item(
          'A',
          vencida: 10,
          saldoVencido: 200,
          vence: true,
          ultima: DateTime(2026, 10, 15),
        ),
      )!;
      // 54 (atraso) + 35 (vence) + 11,5 (reativação)
      expect(r.pontos, closeTo(100.5, 1e-9));
      expect(r.motivo, MotivoVisita.cobrancaEmAtraso);
    });

    test('cobrar vem antes de vender: atraso curto > inatividade enorme', () {
      final atraso = _pontuar(_item('A', vencida: 1))!;
      final inativo = _pontuar(
        _item('B', score: ScoreCliente.a, ultima: DateTime(2020, 1, 1)),
      )!;
      expect(atraso.pontos, greaterThan(inativo.pontos));
    });

    test('vence na data > inatividade máxima de um score A', () {
      final vence = _pontuar(_item('A', vence: true))!;
      final inativo = _pontuar(
        _item('B', score: ScoreCliente.a, ultima: DateTime(2020, 1, 1)),
      )!;
      expect(vence.pontos, greaterThan(inativo.pontos));
    });
  });

  group('motivo principal e texto', () {
    test('o maior fator define o motivo', () {
      expect(
        _pontuar(_item('A', vence: true, ultima: DateTime(2026, 10, 1)))!
            .motivo,
        MotivoVisita.venceNaData,
      );
      expect(
        _pontuar(_item('B', vencida: 3, vence: true))!.motivo,
        MotivoVisita.cobrancaEmAtraso,
      );
    });

    test('textos: atraso singular/plural, vence hoje e vence na data', () {
      expect(
        _pontuar(_item('A', vencida: 12))!.textoMotivo,
        'Parcela vencida há 12 dias',
      );
      expect(
        _pontuar(_item('A', vencida: 1))!.textoMotivo,
        'Parcela vencida há 1 dia',
      );
      expect(_pontuar(_item('A', vence: true))!.textoMotivo, 'Vence hoje');
      // Agenda em outra data: "hoje" não faz sentido.
      final outra = pontuarVisita(
        _item('A', vence: true),
        regra: _regra,
        data: DateTime(2026, 11, 20),
        hoje: _hoje,
      )!;
      expect(outra.textoMotivo, 'Vence nesta data');
    });

    test('rótulos dos selos', () {
      expect(MotivoVisita.cobrancaEmAtraso.rotulo, 'Em atraso');
      expect(MotivoVisita.venceNaData.rotulo, 'Vence na data');
      expect(MotivoVisita.reativacao.rotulo, 'Reativar');
      expect(MotivoVisita.clienteNovo.rotulo, 'Sem compras');
      expect(MotivoVisita.bloqueadoCobrar.rotulo, 'Bloqueado: cobrar');
    });
  });

  group('cliente bloqueado: só cobrança', () {
    test('com atraso continua recomendado, como "Bloqueado: cobrar"', () {
      final r = _pontuar(
        _item('A', bloqueado: true, vencida: 12, saldoVencido: 100),
      )!;
      expect(r.motivo, MotivoVisita.bloqueadoCobrar);
      expect(r.textoMotivo, 'Bloqueado: cobrar · parcela vencida há 12 dias');
      // Atraso conta normalmente: (40 + 12 + 2) × 1.
      expect(r.pontos, closeTo(54, 1e-9));
    });

    test('com parcela vencendo na data também cobra', () {
      final r = _pontuar(_item('A', bloqueado: true, vence: true))!;
      expect(r.motivo, MotivoVisita.bloqueadoCobrar);
      expect(r.textoMotivo, 'Bloqueado: cobrar · vence hoje');
    });

    test('inatividade não conta: bloqueado sem nada a cobrar fica de fora', () {
      expect(
        _pontuar(_item('A', bloqueado: true, ultima: DateTime(2025, 1, 1))),
        isNull,
      );
    });

    test('nunca comprou não conta para bloqueado', () {
      expect(_pontuar(_item('A', bloqueado: true, semCompra: true)), isNull);
    });

    test('bloqueado com atraso não ganha pontos de reativação', () {
      final r = _pontuar(
        _item('A', bloqueado: true, vencida: 10, ultima: DateTime(2025, 1, 1)),
      )!;
      expect(r.pontos, closeTo(50, 1e-9)); // só o atraso
    });
  });

  group('recomendarVisitas', () {
    test('ordena por pontos e desempata por nome sem acento', () {
      final lista = recomendarVisitas(
        [
          _item('Zeca', vencida: 5),
          _item('Ângela', vencida: 5),
          _item('Beto', vencida: 5),
          _item('Caio', vencida: 30),
        ],
        regra: _regra,
        data: _data,
        hoje: _hoje,
      );
      expect(_nomes(lista), ['Caio', 'Ângela', 'Beto', 'Zeca']);
    });

    test('só entram os clientes com pontuação', () {
      final lista = recomendarVisitas(
        [_item('Quitado'), _item('Atrasado', vencida: 2)],
        regra: _regra,
        data: _data,
        hoje: _hoje,
      );
      expect(_nomes(lista), ['Atrasado']);
    });

    test('dispensados saem da lista', () {
      final itens = [_item('A', vencida: 5), _item('B', vencida: 9)];
      final lista = recomendarVisitas(
        itens,
        regra: _regra,
        data: _data,
        hoje: _hoje,
        dispensados: {'c-B'},
      );
      expect(_nomes(lista), ['A']);
    });

    test('lista vazia', () {
      expect(
        recomendarVisitas(const [], regra: _regra, data: _data, hoje: _hoje),
        isEmpty,
      );
    });

    test('limite de N: só os melhores', () {
      final lista = recomendarVisitas(
        [for (var i = 1; i <= 8; i++) _item('N$i', vencida: i)],
        regra: _regra,
        data: _data,
        hoje: _hoje,
      );
      expect(lista, hasLength(8));
      expect(_nomes(melhoresRecomendacoes(lista, _regra)), [
        'N8',
        'N7',
        'N6',
        'N5',
        'N4',
      ]);
      expect(
        melhoresRecomendacoes(lista, _regra.copyWith(quantidade: 2)),
        hasLength(2),
      );
      // Menos que N: devolve todos.
      expect(
        melhoresRecomendacoes(lista.take(3).toList(), _regra),
        hasLength(3),
      );
    });

    test('regra com pesos alterados muda a ordem', () {
      final itens = [
        _item('Atrasado', vencida: 3),
        _item('Inativo', score: ScoreCliente.a, ultima: DateTime(2026, 7, 1)),
      ];
      expect(
        _nomes(
          recomendarVisitas(itens, regra: _regra, data: _data, hoje: _hoje),
        ),
        ['Atrasado', 'Inativo'],
      );
      final vendas = _regra.copyWith(
        pesoAtrasoBase: 1,
        pesoInatividadeBase: 100,
        multiplicadorCobranca: const {ScoreCliente.b: 0.1},
      );
      expect(
        _nomes(
          recomendarVisitas(itens, regra: vendas, data: _data, hoje: _hoje),
        ),
        ['Inativo', 'Atrasado'],
      );
    });

    test('limite de inatividade configurável', () {
      final item = _item('A', ultima: DateTime(2026, 10, 25)); // 20 dias
      expect(_pontuar(item), isNull);
      expect(
        _pontuar(item, regra: _regra.copyWith(diasInatividade: 15)),
        isNotNull,
      );
    });

    test('data futura da agenda: mais dias sem comprar entram', () {
      final item = _item('A', ultima: DateTime(2026, 10, 25)); // 20 dias
      expect(
        recomendarVisitas([item], regra: _regra, data: _data, hoje: _hoje),
        isEmpty,
      );
      final futura = recomendarVisitas(
        [item],
        regra: _regra,
        data: DateTime(2026, 11, 25), // 31 dias
        hoje: _hoje,
      );
      expect(futura.single.textoMotivo, 'Sem comprar há 31 dias');
    });

    test('data passada anterior à última compra não pontua inatividade', () {
      final item = _item('A', ultima: DateTime(2026, 11, 10));
      expect(
        recomendarVisitas(
          [item],
          regra: _regra,
          data: DateTime(2026, 11, 1),
          hoje: _hoje,
        ),
        isEmpty,
      );
    });
  });

  group('rota específica x todas', () {
    RotaModel rota(String id, String nome) => RotaModel(
      id: id,
      codigo: 'R-$id',
      nome: nome,
      linhaAtendimento: LinhaAtendimento.toledo,
      updatedAt: _t,
    );

    ClienteModel atrasado(String nome, String? rotaId) => ClienteModel(
      id: 'c-$nome',
      codigo: 'C-$nome',
      nome: nome,
      cpf: '52998224725',
      telefone: '',
      endereco: '',
      rotaId: rotaId,
      ultimaCompra: _recente,
      valorEmAberto: 100,
      proximoVencimento: DateTime(2026, 11, 10),
      updatedAt: _t,
    );

    List<String> recomendados({String? rotaId}) {
      final itens = montarAgenda(
        clientes: [
          atrasado('NaA', 'a'),
          atrasado('NaB', 'b'),
          atrasado('SemRota', null),
        ],
        rotas: [rota('a', 'Centro'), rota('b', 'Norte')],
        data: _data,
        rotaId: rotaId,
        parcelasPendentesPorCliente: null, // estimado pelo resumo
        regra: const RegraBloqueio(),
        agora: _hoje,
      );
      return _nomes(
        recomendarVisitas(itens, regra: _regra, data: _data, hoje: _hoje),
      );
    }

    test('rota específica considera só os clientes dela', () {
      expect(recomendados(rotaId: 'a'), ['NaA']);
    });

    test('todas as rotas considera todos, inclusive sem rota', () {
      expect(recomendados(), ['NaA', 'NaB', 'SemRota']);
    });
  });

  group('filtrarRecomendacoes / motivosPresentes', () {
    late List<Recomendacao> lista;
    setUp(() {
      lista = recomendarVisitas(
        [
          _item('Ângela', vencida: 5),
          _item('Beto', vence: true),
          _item('Caio', ultima: DateTime(2026, 8, 1)),
          _item('Dora', semCompra: true),
        ],
        regra: _regra,
        data: _data,
        hoje: _hoje,
      );
    });

    test('sem filtro devolve todos', () {
      expect(filtrarRecomendacoes(lista), hasLength(4));
    });

    test('por motivo', () {
      expect(
        _nomes(filtrarRecomendacoes(lista, motivo: MotivoVisita.reativacao)),
        ['Caio'],
      );
    });

    test('busca por nome sem acento e sem maiúsculas', () {
      expect(_nomes(filtrarRecomendacoes(lista, termo: 'angela')), ['Ângela']);
      expect(_nomes(filtrarRecomendacoes(lista, termo: 'DOR')), ['Dora']);
      expect(filtrarRecomendacoes(lista, termo: 'zzz'), isEmpty);
    });

    test('motivo e busca combinam', () {
      expect(
        filtrarRecomendacoes(
          lista,
          motivo: MotivoVisita.venceNaData,
          termo: 'caio',
        ),
        isEmpty,
      );
    });

    test('motivos presentes, na ordem do enum', () {
      expect(motivosPresentes(lista), [
        MotivoVisita.cobrancaEmAtraso,
        MotivoVisita.venceNaData,
        MotivoVisita.reativacao,
        MotivoVisita.clienteNovo,
      ]);
      expect(motivosPresentes(const []), isEmpty);
    });
  });
}
