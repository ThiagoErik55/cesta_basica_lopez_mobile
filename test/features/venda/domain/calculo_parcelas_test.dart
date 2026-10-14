import 'package:cesta_basica_lopez_mobile/features/venda/domain/calculo_parcelas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gerarParcelas', () {
    test('divide sem perder centavos, sobra vai na primeira', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 100,
        quantidade: 3,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.map((p) => p.valor), [33.34, 33.33, 33.33]);
      final soma = parcelas.fold<double>(0, (s, p) => s + p.valor);
      expect(soma, closeTo(100, 0.001));
    });

    test('numera e vence mês a mês', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 90,
        quantidade: 3,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.map((p) => p.numero), [1, 2, 3]);
      expect(parcelas.map((p) => p.vencimento), [
        DateTime(2026, 11, 10),
        DateTime(2026, 12, 10),
        DateTime(2027, 1, 10),
      ]);
      expect(parcelas.every((p) => p.vendaId == 'v1' && !p.pago), isTrue);
    });

    test('uma parcela fica com o total', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 129.9,
        quantidade: 1,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.single.valor, 129.9);
    });
  });

  group('somarMeses', () {
    test('dia 31 cai no último dia do mês curto', () {
      expect(somarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(somarMeses(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('vira o ano', () {
      expect(somarMeses(DateTime(2026, 12, 5), 1), DateTime(2027, 1, 5));
    });
  });
}
