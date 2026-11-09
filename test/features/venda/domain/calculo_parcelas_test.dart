import 'package:cesta_basica_lopez_mobile/features/venda/domain/calculo_parcelas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gerarParcelas', () {
    test('divide sem perder centavos, sobra vai na última', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 100,
        quantidade: 3,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.map((p) => p.valor), [33.33, 33.33, 33.34]);
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

    test('divisão exata não altera nenhuma parcela', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 90,
        quantidade: 3,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.map((p) => p.valor), [30, 30, 30]);
    });

    test('soma das parcelas é sempre o total, em vários cenários', () {
      for (final total in [0.01, 10.0, 99.99, 123.45, 1000.01]) {
        for (var n = 2; n <= 12; n++) {
          final parcelas = gerarParcelas(
            vendaId: 'v1',
            total: total,
            quantidade: n,
            primeiroVencimento: DateTime(2026, 11, 10),
          );
          final centavos = parcelas.fold<int>(
            0,
            (s, p) => s + (p.valor * 100).round(),
          );
          expect(centavos, (total * 100).round(), reason: '$total em $n');
        }
      }
    });

    test('ids únicos e status inicial pendente', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 50,
        quantidade: 4,
        primeiroVencimento: DateTime(2026, 11, 10),
      );
      expect(parcelas.map((p) => p.id).toSet(), hasLength(4));
      expect(parcelas.every((p) => !p.pago && p.pagamentos.isEmpty), isTrue);
    });

    test('vencimentos de fim de mês partem sempre do dia original', () {
      final parcelas = gerarParcelas(
        vendaId: 'v1',
        total: 120,
        quantidade: 4,
        primeiroVencimento: DateTime(2026, 1, 31),
      );
      expect(parcelas.map((p) => p.vencimento), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
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

  group('validarParcelamento', () {
    final hoje = DateTime(2026, 11, 9, 15, 30);

    test('aceita 2 parcelas com vencimento hoje ou futuro', () {
      expect(
        validarParcelamento(
          quantidade: 2,
          primeiroVencimento: DateTime(2026, 11, 9),
          hoje: hoje,
        ),
        isNull,
      );
      expect(
        validarParcelamento(
          quantidade: 12,
          primeiroVencimento: DateTime(2026, 12, 9),
          hoje: hoje,
        ),
        isNull,
      );
    });

    test('recusa menos de 2 parcelas', () {
      expect(
        validarParcelamento(
          quantidade: 1,
          primeiroVencimento: DateTime(2026, 12, 9),
          hoje: hoje,
        ),
        isNotNull,
      );
    });

    test('recusa data anterior a hoje', () {
      expect(
        validarParcelamento(
          quantidade: 3,
          primeiroVencimento: DateTime(2026, 11, 8),
          hoje: hoje,
        ),
        isNotNull,
      );
    });
  });
}
