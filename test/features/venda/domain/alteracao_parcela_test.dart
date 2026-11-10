import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/alteracao_parcela.dart';
import 'package:flutter_test/flutter_test.dart';

ParcelaModel parcela(int numero, double valor, {bool pago = false}) =>
    ParcelaModel(
      id: 'p$numero',
      vendaId: 'v1',
      numero: numero,
      valor: valor,
      vencimento: DateTime(2026, 12, numero),
      pago: pago,
      updatedAt: DateTime(2026, 11, 9),
    );

List<double> valores(ResultadoAlteracaoParcela r) =>
    r.parcelasResultantes.map((p) => p.valor).toList();

void main() {
  final agora = DateTime(2026, 11, 9, 10);

  ResultadoAlteracaoParcela alterar(
    List<ParcelaModel> parcelas,
    String id,
    double novo, {
    ModoCompensacao modo = ModoCompensacao.redistribuir,
    String? motivo,
  }) => alterarValorParcela(
    parcelas: parcelas,
    parcelaId: id,
    novoValor: novo,
    modo: modo,
    valorTotalVenda: parcelas.fold(0.0, (s, p) => s + p.valor),
    motivo: motivo,
    agora: agora,
  );

  group('redistribuir', () {
    test('reparte a diferença em partes iguais e mantém o total', () {
      final r = alterar(
        [parcela(1, 100), parcela(2, 100), parcela(3, 100)],
        'p1',
        120,
      );
      expect(r.ok, isTrue);
      expect(valores(r), [120, 90, 90]);
      expect(r.diferencaTotal, 0);
      expect(r.totalNovo, 300);
    });

    test('centavos que não dividem certo vão para a última', () {
      final r = alterar(
        [parcela(1, 100), parcela(2, 100), parcela(3, 100), parcela(4, 100)],
        'p1',
        110,
      );
      // -10,00 em 3 = -3,33 -3,33 -3,34
      expect(valores(r), [110, 96.67, 96.67, 96.66]);
      final soma = r.parcelasResultantes.fold<int>(
        0,
        (s, p) => s + (p.valor * 100).round(),
      );
      expect(soma, 40000);
    });

    test('aumentar o valor do meio redistribui só nas pendentes', () {
      final r = alterar(
        [parcela(1, 100, pago: true), parcela(2, 100), parcela(3, 100)],
        'p2',
        60,
      );
      expect(valores(r), [100, 60, 140]);
    });

    test('parcela paga fica intocada', () {
      final paga = parcela(1, 100, pago: true);
      final r = alterar([paga, parcela(2, 100), parcela(3, 100)], 'p2', 150);
      expect(r.parcelasResultantes.first, same(paga));
      expect(r.alteradas.map((a) => a.parcelaId), ['p2', 'p3']);
    });

    test('registra histórico em todas as parcelas alteradas', () {
      final r = alterar(
        [parcela(1, 100), parcela(2, 100)],
        'p1',
        130,
        motivo: '  cliente pediu  ',
      );
      final principal = r.alteradas.first.alteracao;
      expect(principal.valorAnterior, 100);
      expect(principal.valorNovo, 130);
      expect(principal.data, agora);
      expect(principal.motivo, 'cliente pediu');
      final outra = r.alteradas.last.alteracao;
      expect(outra.valorNovo, 70);
      expect(outra.motivo, contains('1ª'));
      expect(r.parcelasResultantes.first.alteracoes, hasLength(1));
    });

    test('recusa quando outra parcela ficaria negativa', () {
      final r = alterar([parcela(1, 100), parcela(2, 50)], 'p1', 200);
      expect(r.ok, isFalse);
      expect(r.erro, contains('2ª'));
    });

    test('recusa quando fica exatamente zero', () {
      final r = alterar([parcela(1, 100), parcela(2, 50)], 'p1', 150);
      expect(r.ok, isFalse);
    });

    test('sem outras pendentes não há redistribuição', () {
      final r = alterar(
        [parcela(1, 100, pago: true), parcela(2, 100)],
        'p2',
        80,
      );
      expect(r.ok, isFalse);
      expect(r.erro, contains('outras parcelas pendentes'));
    });
  });

  group('ajustarSomente', () {
    test('muda só a parcela e o total da venda', () {
      final r = alterar(
        [parcela(1, 100), parcela(2, 100)],
        'p1',
        130,
        modo: ModoCompensacao.ajustarSomente,
      );
      expect(r.ok, isTrue);
      expect(valores(r), [130, 100]);
      expect(r.totalAnterior, 200);
      expect(r.totalNovo, 230);
      expect(r.diferencaTotal, 30);
      expect(r.alteradas, hasLength(1));
    });

    test('funciona sem outras pendentes e com redução', () {
      final r = alterar(
        [parcela(1, 100, pago: true), parcela(2, 100)],
        'p2',
        80,
        modo: ModoCompensacao.ajustarSomente,
      );
      expect(r.ok, isTrue);
      expect(r.totalNovo, 180);
      expect(r.diferencaTotal, -20);
    });
  });

  group('validações', () {
    test('parcela paga não pode ser alterada', () {
      final r = alterar(
        [parcela(1, 100, pago: true), parcela(2, 100)],
        'p1',
        90,
      );
      expect(r.ok, isFalse);
      expect(r.erro, contains('paga'));
    });

    test('valor zero ou negativo é recusado', () {
      for (final v in [0.0, -5.0]) {
        final r = alterar(
          [parcela(1, 100), parcela(2, 100)],
          'p1',
          v,
          modo: ModoCompensacao.ajustarSomente,
        );
        expect(r.ok, isFalse, reason: '$v');
      }
    });

    test('valor igual ao atual é recusado', () {
      expect(
        alterar([parcela(1, 100), parcela(2, 100)], 'p1', 100).ok,
        isFalse,
      );
    });

    test('valor menor ou igual ao já pago é recusado', () {
      final parcial = parcela(1, 100).copyWith(
        pagamentos: [
          PagamentoModel(
            id: 'g1',
            valor: 40,
            data: DateTime(2026, 11, 1),
            forma: FormaPagamento.dinheiro,
          ),
        ],
      );
      final r = alterar(
        [parcial, parcela(2, 100)],
        'p1',
        40,
        modo: ModoCompensacao.ajustarSomente,
      );
      expect(r.ok, isFalse);
    });

    test('parcela inexistente', () {
      expect(alterar([parcela(1, 100)], 'x', 50).ok, isFalse);
    });
  });
}
