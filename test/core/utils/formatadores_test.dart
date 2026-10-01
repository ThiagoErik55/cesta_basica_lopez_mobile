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
}
