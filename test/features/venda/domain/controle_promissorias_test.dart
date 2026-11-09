import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/controle_promissorias.dart';
import 'package:flutter_test/flutter_test.dart';

final passado = DateTime(2020, 1, 1);
final futuro = DateTime(2099, 1, 1);

VendaModel venda(
  String id, {
  int nota = 1,
  String cliente = 'Maria',
  DateTime? data,
  TipoVenda tipo = TipoVenda.parcelado,
  double total = 100,
  bool deleted = false,
}) => VendaModel(
  id: id,
  clienteId: 'c-$cliente',
  clienteNome: cliente,
  vendedorUid: 'u',
  numeroNota: nota,
  data: data ?? DateTime(2026, 10, 1),
  itens: const [],
  valorTotal: total,
  tipo: tipo,
  updatedAt: DateTime(2026, 10, 1),
  deleted: deleted,
);

ParcelaModel parcela(
  String vendaId,
  int numero,
  double valor, {
  bool pago = false,
  DateTime? vencimento,
  double pagoParcial = 0,
}) => ParcelaModel(
  id: '$vendaId-$numero',
  vendaId: vendaId,
  numero: numero,
  valor: valor,
  vencimento: vencimento ?? futuro,
  pago: pago,
  pagamentos: [
    if (pago)
      PagamentoModel(
        id: 'g$vendaId$numero',
        valor: valor,
        data: DateTime(2026, 10, 5),
        forma: FormaPagamento.pix,
      )
    else if (pagoParcial > 0)
      PagamentoModel(
        id: 'p$vendaId$numero',
        valor: pagoParcial,
        data: DateTime(2026, 10, 5),
        forma: FormaPagamento.pix,
      ),
  ],
  updatedAt: DateTime(2026, 10, 1),
);

ItemPromissoria item(VendaModel v, List<ParcelaModel> ps) =>
    ItemPromissoria.de(v, ps);

void main() {
  group('ItemPromissoria', () {
    test('em dia: nada vencido, saldo é o que falta', () {
      final i = item(venda('a'), [
        parcela('a', 1, 50, pago: true),
        parcela('a', 2, 50, vencimento: DateTime(2099, 2, 1)),
      ]);
      expect(i.situacao, StatusPromissoria.aberta);
      expect(i.valorPago, 50);
      expect(i.saldo, 50);
      expect(i.saldoEmAtraso, 0);
      expect(i.parcelasPagas, 1);
      expect(i.totalParcelas, 2);
      expect(i.proximoVencimento, DateTime(2099, 2, 1));
    });

    test('em atraso: parcela pendente vencida', () {
      final i = item(venda('a'), [
        parcela('a', 1, 40, vencimento: passado),
        parcela('a', 2, 60),
      ]);
      expect(i.situacao, StatusPromissoria.atrasada);
      expect(i.emAtraso, isTrue);
      expect(i.saldo, 100);
      expect(i.saldoEmAtraso, 40);
      expect(i.proximoVencimento, passado);
    });

    test('parcela vencida já paga não deixa em atraso', () {
      final i = item(venda('a'), [
        parcela('a', 1, 40, pago: true, vencimento: passado),
        parcela('a', 2, 60),
      ]);
      expect(i.situacao, StatusPromissoria.aberta);
    });

    test('quitada: todas pagas, sem próximo vencimento', () {
      final i = item(venda('a'), [
        parcela('a', 1, 50, pago: true),
        parcela('a', 2, 50, pago: true),
      ]);
      expect(i.situacao, StatusPromissoria.paga);
      expect(i.saldo, 0);
      expect(i.valorPago, 100);
      expect(i.proximoVencimento, isNull);
    });

    test('pagamento parcial entra no valor pago e reduz o saldo', () {
      final i = item(venda('a'), [
        parcela('a', 1, 100, pagoParcial: 30, vencimento: passado),
      ]);
      expect(i.valorPago, 30);
      expect(i.saldo, 70);
      expect(i.saldoEmAtraso, 70);
      expect(i.parcelasPagas, 0);
    });

    test('sem parcelas carregadas: em dia, e não quitada', () {
      final i = item(venda('a'), const []);
      expect(i.situacao, StatusPromissoria.aberta);
      expect(i.totalParcelas, 0);
    });

    test('ignora parcelas removidas', () {
      final removida = ParcelaModel(
        id: 'x',
        vendaId: 'a',
        numero: 3,
        valor: 999,
        vencimento: passado,
        updatedAt: DateTime(2026, 1, 1),
        deleted: true,
      );
      final i = item(venda('a'), [parcela('a', 1, 50, pago: true), removida]);
      expect(i.situacao, StatusPromissoria.paga);
      expect(i.totalParcelas, 1);
    });
  });

  group('montarItensPromissoria', () {
    test('só vendas parceladas e não removidas', () {
      final itens = montarItensPromissoria(
        vendas: [
          venda('p1'),
          venda('v', tipo: TipoVenda.aVista),
          venda('d', deleted: true),
        ],
        parcelasPorVenda: {
          'p1': [parcela('p1', 1, 100)],
        },
      );
      expect(itens.map((i) => i.vendaId), ['p1']);
    });
  });

  group('resumirPromissorias', () {
    test('soma saldo, saldo vencido e conta promissórias em atraso', () {
      final itens = [
        item(venda('a'), [
          parcela('a', 1, 40, vencimento: passado),
          parcela('a', 2, 60),
        ]),
        item(venda('b'), [parcela('b', 1, 30)]),
        item(venda('c'), [parcela('c', 1, 25.5, vencimento: passado)]),
        item(venda('d'), [parcela('d', 1, 80, pago: true)]),
      ];
      final r = resumirPromissorias(itens);
      expect(r.totalEmAberto, 155.5);
      expect(r.totalEmAtraso, 65.5);
      expect(r.quantidadeEmAtraso, 2);
    });

    test('lista vazia zera tudo', () {
      final r = resumirPromissorias(const []);
      expect(r.totalEmAberto, 0);
      expect(r.totalEmAtraso, 0);
      expect(r.quantidadeEmAtraso, 0);
    });
  });

  group('ordenarPromissorias', () {
    test('em atraso, depois em dia por vencimento, depois quitadas', () {
      final quitada = item(venda('q', nota: 1, data: DateTime(2026, 9, 1)), [
        parcela('q', 1, 10, pago: true),
      ]);
      final quitadaNova = item(
        venda('q2', nota: 2, data: DateTime(2026, 10, 1)),
        [parcela('q2', 1, 10, pago: true)],
      );
      final emDiaLonge = item(venda('l', nota: 3), [
        parcela('l', 1, 10, vencimento: DateTime(2099, 6, 1)),
      ]);
      final emDiaPerto = item(venda('p', nota: 4), [
        parcela('p', 1, 10, vencimento: DateTime(2099, 3, 1)),
      ]);
      final atrasoAntigo = item(venda('aa', nota: 5), [
        parcela('aa', 1, 10, vencimento: DateTime(2020, 1, 1)),
      ]);
      final atrasoRecente = item(venda('ar', nota: 6), [
        parcela('ar', 1, 10, vencimento: DateTime(2021, 1, 1)),
      ]);

      final ordenada = ordenarPromissorias([
        quitada,
        emDiaLonge,
        atrasoRecente,
        quitadaNova,
        emDiaPerto,
        atrasoAntigo,
      ]);
      expect(ordenada.map((i) => i.numeroNota), [5, 6, 4, 3, 2, 1]);
    });

    test('empate de vencimento sai pela nota mais nova', () {
      final a = item(venda('a', nota: 1), [parcela('a', 1, 10)]);
      final b = item(venda('b', nota: 2), [parcela('b', 1, 10)]);
      expect(ordenarPromissorias([a, b]).map((i) => i.numeroNota), [2, 1]);
    });
  });

  group('filtrarPromissorias', () {
    final atrasada = item(venda('a', nota: 1001, cliente: 'João Silva'), [
      parcela('a', 1, 10, vencimento: passado),
    ]);
    final emDia = item(venda('b', nota: 2002, cliente: 'Maria Souza'), [
      parcela('b', 1, 10),
    ]);
    final quitada = item(venda('c', nota: 3003, cliente: 'Ana Lima'), [
      parcela('c', 1, 10, pago: true),
    ]);
    final todos = [atrasada, emDia, quitada];

    test('sem filtro devolve todas', () {
      expect(filtrarPromissorias(todos), hasLength(3));
    });

    test('por situação', () {
      expect(filtrarPromissorias(todos, situacao: StatusPromissoria.atrasada), [
        atrasada,
      ]);
      expect(filtrarPromissorias(todos, situacao: StatusPromissoria.aberta), [
        emDia,
      ]);
      expect(filtrarPromissorias(todos, situacao: StatusPromissoria.paga), [
        quitada,
      ]);
    });

    test('busca por parte do número da nota', () {
      expect(filtrarPromissorias(todos, termo: '2002'), [emDia]);
      expect(filtrarPromissorias(todos, termo: '300'), [quitada]);
    });

    test('busca por nome sem diferenciar maiúsculas nem acentos', () {
      expect(filtrarPromissorias(todos, termo: 'joao'), [atrasada]);
      expect(filtrarPromissorias(todos, termo: 'JOÃO sil'), [atrasada]);
      expect(filtrarPromissorias(todos, termo: 'souza'), [emDia]);
    });

    test('situação e busca combinadas', () {
      expect(
        filtrarPromissorias(
          todos,
          situacao: StatusPromissoria.atrasada,
          termo: 'maria',
        ),
        isEmpty,
      );
    });

    test('termo só com espaços não filtra', () {
      expect(filtrarPromissorias(todos, termo: '   '), hasLength(3));
    });
  });
}
