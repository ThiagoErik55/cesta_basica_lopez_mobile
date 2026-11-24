import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 18/11/2026 é quarta-feira.
  final quarta = DateTime(2026, 11, 18, 15, 30);

  group('hoje', () {
    test('vai da meia-noite à meia-noite seguinte, sem horário', () {
      final p = Periodo.hoje(quarta);
      expect(p.inicio, DateTime(2026, 11, 18));
      expect(p.fim, DateTime(2026, 11, 19));
      expect(p.dias, 1);
    });

    test('contém 23:59 do dia e não contém 00:00 do seguinte', () {
      final p = Periodo.hoje(quarta);
      expect(p.contem(DateTime(2026, 11, 18, 23, 59, 59)), isTrue);
      expect(p.contem(DateTime(2026, 11, 19)), isFalse);
      expect(p.contem(DateTime(2026, 11, 17, 23, 59, 59)), isFalse);
    });

    test('virada de mês e de ano', () {
      final p = Periodo.hoje(DateTime(2026, 12, 31, 22));
      expect(p.fim, DateTime(2027, 1, 1));
    });
  });

  group('semana', () {
    test('começa na segunda e termina no domingo', () {
      final p = Periodo.semana(quarta);
      expect(p.inicio, DateTime(2026, 11, 16));
      expect(p.fim, DateTime(2026, 11, 23));
      expect(p.dias, 7);
      expect(p.ultimoDia, DateTime(2026, 11, 22));
    });

    test('segunda e domingo pertencem à mesma semana', () {
      expect(
        Periodo.semana(DateTime(2026, 11, 16)).inicio,
        DateTime(2026, 11, 16),
      );
      expect(
        Periodo.semana(DateTime(2026, 11, 22)).inicio,
        DateTime(2026, 11, 16),
      );
      expect(
        Periodo.semana(DateTime(2026, 11, 23)).inicio,
        DateTime(2026, 11, 23),
      );
    });

    test('atravessa a virada de mês', () {
      final p = Periodo.semana(DateTime(2026, 12, 2));
      expect(p.inicio, DateTime(2026, 11, 30));
      expect(p.fim, DateTime(2026, 12, 7));
    });
  });

  group('mês', () {
    test('novembro tem 30 dias', () {
      final p = Periodo.mes(quarta);
      expect(p.inicio, DateTime(2026, 11));
      expect(p.fim, DateTime(2026, 12));
      expect(p.dias, 30);
    });

    test('dezembro termina em janeiro do ano seguinte', () {
      final p = Periodo.mes(DateTime(2026, 12, 15));
      expect(p.fim, DateTime(2027, 1));
      expect(p.dias, 31);
    });

    test('fevereiro de ano não bissexto tem 28 dias', () {
      expect(Periodo.mes(DateTime(2026, 2, 10)).dias, 28);
    });

    test('virada de mês separa 30/11 de 01/12', () {
      final p = Periodo.mes(quarta);
      expect(p.contem(DateTime(2026, 11, 30, 23, 59)), isTrue);
      expect(p.contem(DateTime(2026, 12)), isFalse);
    });
  });

  group('personalizado', () {
    test('inclui o último dia escolhido', () {
      final p = Periodo.personalizado(
        DateTime(2026, 11, 10, 9),
        DateTime(2026, 11, 12, 20),
      );
      expect(p.inicio, DateTime(2026, 11, 10));
      expect(p.fim, DateTime(2026, 11, 13));
      expect(p.dias, 3);
    });

    test('datas invertidas são trocadas', () {
      final p = Periodo.personalizado(
        DateTime(2026, 11, 12),
        DateTime(2026, 11, 10),
      );
      expect(p.inicio, DateTime(2026, 11, 10));
      expect(p.dias, 3);
    });

    test('um único dia', () {
      final p = Periodo.personalizado(
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10),
      );
      expect(p.dias, 1);
    });

    test('limita o intervalo a $maximoDiasPersonalizado dias', () {
      final p = Periodo.personalizado(
        DateTime(2026, 1, 1),
        DateTime(2026, 11, 1),
      );
      expect(p.dias, maximoDiasPersonalizado);
      expect(p.inicio, DateTime(2026, 1, 1));
    });
  });

  group('período anterior', () {
    test('de hoje é ontem', () {
      final a = Periodo.hoje(quarta).anterior;
      expect(a.inicio, DateTime(2026, 11, 17));
      expect(a.fim, DateTime(2026, 11, 18));
    });

    test('da semana é a semana imediatamente anterior', () {
      final a = Periodo.semana(quarta).anterior;
      expect(a.inicio, DateTime(2026, 11, 9));
      expect(a.fim, DateTime(2026, 11, 16));
    });

    test('do mês tem a mesma duração e termina onde o mês começa', () {
      final p = Periodo.mes(quarta);
      final a = p.anterior;
      expect(a.dias, p.dias);
      expect(a.fim, p.inicio);
      expect(a.inicio, DateTime(2026, 10, 2));
    });

    test('do personalizado tem a mesma duração', () {
      final p = Periodo.personalizado(
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 14),
      );
      expect(p.anterior.inicio, DateTime(2026, 11, 5));
      expect(p.anterior.fim, DateTime(2026, 11, 10));
    });
  });

  test('diasDoPeriodo lista um dia por posição', () {
    final dias = Periodo.semana(quarta).diasDoPeriodo;
    expect(dias.length, 7);
    expect(dias.first, DateTime(2026, 11, 16));
    expect(dias.last, DateTime(2026, 11, 22));
  });
}
