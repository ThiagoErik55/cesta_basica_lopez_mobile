import 'package:cesta_basica_lopez_mobile/core/utils/formatadores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatarMoeda usa padrão brasileiro', () {
    // NumberFormat separa o símbolo com espaço não separável.
    expect(formatarMoeda(1234.5).replaceAll(' ', ' '), r'R$ 1.234,50');
    expect(formatarMoeda(0).replaceAll(' ', ' '), r'R$ 0,00');
  });

  test('formatarData', () {
    expect(formatarData(DateTime(2026, 9, 20)), '20/09/2026');
    expect(formatarData(null), '—');
    expect(formatarData(null, vazio: 'Nenhuma'), 'Nenhuma');
  });

  test('formatarValorEditavel e lerValorMonetario', () {
    expect(formatarValorEditavel(150), '150,00');
    expect(formatarValorEditavel(0.5), '0,50');
    expect(lerValorMonetario('150'), 150);
    expect(lerValorMonetario('150,5'), 150.5);
    expect(lerValorMonetario('150.50'), 150.5);
    expect(lerValorMonetario(''), isNull);
    expect(lerValorMonetario(','), isNull);
  });

  test('formatarDataHora mostra data e hora', () {
    expect(formatarDataHora(DateTime(2026, 11, 9, 14, 5)), '09/11/2026 14:05');
  });

  test('formatarCentavos formata inteiros sem ponto flutuante', () {
    expect(formatarCentavos(0), r'R$ 0,00');
    expect(formatarCentavos(5), r'R$ 0,05');
    expect(formatarCentavos(123456), r'R$ 1.234,56');
    expect(formatarCentavos(100000000), r'R$ 1.000.000,00');
    expect(formatarCentavos(-500), r'−R$ 5,00');
  });
}
