import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/registro_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

ParcelaModel parcela(
  int numero,
  double valor, {
  bool pago = false,
  List<PagamentoModel> pagamentos = const [],
  DateTime? vencimento,
}) => ParcelaModel(
  id: 'p$numero',
  vendaId: 'v1',
  numero: numero,
  valor: valor,
  vencimento: vencimento ?? DateTime(2026, 12, numero),
  pago: pago,
  pagamentos: pagamentos,
  updatedAt: DateTime(2026, 11, 1),
);

PagamentoModel pagto(double valor) => PagamentoModel(
  id: 'g',
  valor: valor,
  data: DateTime(2026, 11, 1),
  forma: FormaPagamento.pix,
);

void main() {
  final agora = DateTime(2026, 11, 9, 14, 30);

  ResultadoPagamento pagar(
    List<ParcelaModel> parcelas,
    String id,
    double valor, {
    DateTime? data,
    String? observacao,
  }) => registrarPagamentoParcela(
    parcelasDaVenda: parcelas,
    parcelaId: id,
    valor: valor,
    forma: FormaPagamento.dinheiro,
    data: data ?? agora,
    observacao: observacao,
    agora: agora,
    idPagamento: 'novo',
  );

  group('registrarPagamentoParcela', () {
    test('pagamento total quita a parcela', () {
      final r = pagar([parcela(1, 100), parcela(2, 100)], 'p1', 100);
      expect(r.ok, isTrue);
      expect(r.parcelaQuitada, isTrue);
      expect(r.parcelaAtualizada!.pago, isTrue);
      expect(r.parcelaAtualizada!.dataPagamento, agora);
      expect(r.saldoRestante, 0);
      expect(r.vendaQuitada, isFalse);
      expect(r.pagamento!.id, 'novo');
      expect(r.pagamento!.forma, FormaPagamento.dinheiro);
    });

    test('pagamento parcial mantém a parcela pendente com o saldo', () {
      final r = pagar([parcela(1, 100)], 'p1', 30.5, observacao: ' sinal ');
      expect(r.ok, isTrue);
      expect(r.parcelaQuitada, isFalse);
      expect(r.parcelaAtualizada!.pago, isFalse);
      expect(r.parcelaAtualizada!.dataPagamento, isNull);
      expect(r.saldoRestante, 69.5);
      expect(r.parcelaAtualizada!.saldo, closeTo(69.5, 0.001));
      expect(r.pagamento!.observacao, 'sinal');
    });

    test('segundo pagamento completa o saldo e quita', () {
      final jaPagou = parcela(1, 100, pagamentos: [pagto(40)]);
      final r = pagar([jaPagou], 'p1', 60);
      expect(r.parcelaQuitada, isTrue);
      expect(r.parcelaAtualizada!.pagamentos, hasLength(2));
      expect(r.vendaQuitada, isTrue);
    });

    test('quitar a última pendente quita a venda', () {
      final r = pagar([parcela(1, 100, pago: true), parcela(2, 50)], 'p2', 50);
      expect(r.vendaQuitada, isTrue);
    });

    test('valor maior que o saldo é recusado', () {
      final jaPagou = parcela(1, 100, pagamentos: [pagto(40)]);
      final r = pagar([jaPagou], 'p1', 60.01);
      expect(r.ok, isFalse);
      expect(r.erro, contains('saldo'));
    });

    test('valor zero ou negativo é recusado', () {
      for (final v in [0.0, -10.0]) {
        expect(pagar([parcela(1, 100)], 'p1', v).ok, isFalse, reason: '$v');
      }
    });

    test('data futura é recusada, hoje e passado são aceitos', () {
      final ps = [parcela(1, 100)];
      expect(pagar(ps, 'p1', 10, data: DateTime(2026, 11, 10)).ok, isFalse);
      expect(
        pagar(ps, 'p1', 10, data: DateTime(2026, 11, 9, 23, 59)).ok,
        isTrue,
      );
      final antiga = pagar(ps, 'p1', 10, data: DateTime(2026, 11, 1, 18));
      expect(antiga.ok, isTrue);
      expect(antiga.pagamento!.data, DateTime(2026, 11, 1));
    });

    test('parcela já paga é recusada', () {
      final r = pagar([parcela(1, 100, pago: true)], 'p1', 10);
      expect(r.ok, isFalse);
      expect(r.erro, contains('já está paga'));
    });

    test('parcela inexistente é recusada', () {
      expect(pagar([parcela(1, 100)], 'x', 10).ok, isFalse);
    });

    test('usa o valor atual da parcela depois de alterada (KAN-32)', () {
      final alterada = parcela(1, 80);
      expect(pagar([alterada], 'p1', 80).parcelaQuitada, isTrue);
      expect(pagar([alterada], 'p1', 100).ok, isFalse);
    });

    test('centavos não geram resíduo', () {
      final r = pagar([parcela(1, 33.34)], 'p1', 33.34);
      expect(r.parcelaQuitada, isTrue);
    });
  });

  group('proximoVencimentoPendente', () {
    test('menor vencimento entre as pendentes', () {
      final ps = [
        parcela(1, 10, pago: true, vencimento: DateTime(2026, 11, 1)),
        parcela(2, 10, vencimento: DateTime(2027, 1, 5)),
        parcela(3, 10, vencimento: DateTime(2026, 12, 20)),
      ];
      expect(proximoVencimentoPendente(ps), DateTime(2026, 12, 20));
    });

    test('pagamento parcial mantém o vencimento da parcela pendente', () {
      final ps = [
        parcela(1, 100, pagamentos: [pagto(10)]),
      ];
      expect(proximoVencimentoPendente(ps), DateTime(2026, 12, 1));
    });

    test('nulo quando tudo está pago ou não há parcelas', () {
      expect(proximoVencimentoPendente([parcela(1, 10, pago: true)]), isNull);
      expect(proximoVencimentoPendente(const []), isNull);
    });

    test('ignora parcelas removidas', () {
      final apagada = ParcelaModel(
        id: 'x',
        vendaId: 'v',
        numero: 1,
        valor: 1,
        vencimento: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deleted: true,
      );
      expect(proximoVencimentoPendente([apagada]), isNull);
    });
  });
}
