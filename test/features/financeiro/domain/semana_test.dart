import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/semana.dart';
import 'package:flutter_test/flutter_test.dart';

// 18/11/2026 é quarta-feira; a semana vai de 16/11 (segunda) a 22/11.
final _agora = DateTime(2026, 11, 18, 15, 30);

void main() {
  group('semanaDaData', () {
    test('começa na segunda e termina no domingo, fim exclusivo', () {
      final s = semanaDaData(DateTime(2026, 11, 18), _agora);
      expect(s.inicio, DateTime(2026, 11, 16));
      expect(s.fim, DateTime(2026, 11, 23));
      expect(s.ultimoDia, DateTime(2026, 11, 22));
      expect(s.dias, 7);
    });

    test('domingo pertence à semana que termina nele', () {
      final s = semanaDaData(DateTime(2026, 11, 15, 23, 59), _agora);
      expect(s.inicio, DateTime(2026, 11, 9));
      expect(s.ultimoDia, DateTime(2026, 11, 15));
    });

    test('virada de mês: 1º de dezembro cai na semana de 30/11', () {
      final s = semanaDaData(DateTime(2026, 12, 1), DateTime(2026, 12, 20));
      expect(s.inicio, DateTime(2026, 11, 30));
      expect(s.fim, DateTime(2026, 12, 7));
      expect(s.contem(DateTime(2026, 11, 30)), isTrue);
      expect(s.contem(DateTime(2026, 12, 6, 23, 59)), isTrue);
      expect(s.contem(DateTime(2026, 12, 7)), isFalse);
    });

    test('data futura vira a semana corrente', () {
      final s = semanaDaData(DateTime(2027, 3, 10), _agora);
      expect(s.inicio, DateTime(2026, 11, 16));
    });
  });

  group('semanaAnteriorA / semanaSeguinteA', () {
    final corrente = Periodo.semana(_agora);

    test('anterior volta sete dias', () {
      final a = semanaAnteriorA(corrente);
      expect(a.inicio, DateTime(2026, 11, 9));
      expect(a.fim, corrente.inicio);
    });

    test('anterior atravessa a virada de ano', () {
      final a = semanaAnteriorA(Periodo.semana(DateTime(2027, 1, 5)));
      expect(a.inicio, DateTime(2026, 12, 28));
      expect(a.ultimoDia, DateTime(2027, 1, 3));
    });

    test('não existe semana depois da corrente', () {
      expect(semanaSeguinteA(corrente, _agora), isNull);
    });

    test('da anterior, a seguinte é a corrente', () {
      final s = semanaSeguinteA(semanaAnteriorA(corrente), _agora);
      expect(s, corrente);
    });

    test('ehSemanaCorrente', () {
      expect(ehSemanaCorrente(corrente, _agora), isTrue);
      expect(ehSemanaCorrente(semanaAnteriorA(corrente), _agora), isFalse);
    });
  });
}
