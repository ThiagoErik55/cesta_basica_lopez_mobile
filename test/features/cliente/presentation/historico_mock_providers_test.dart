import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/historico_mock_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'd95e4277-8f86-4e2c-9a1b-000000000010';

  List<int> notas(ProviderContainer c, String id) =>
      c.read(comprasMockProvider(id)).map((x) => x.numeroNota).toList();

  test('mesmo cliente recebe o mesmo histórico em containers diferentes', () {
    final a = ProviderContainer();
    final b = ProviderContainer();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    expect(notas(a, id), notas(b, id));
    expect(
      a.read(pagamentosMockProvider(id)).map((p) => p.valor),
      b.read(pagamentosMockProvider(id)).map((p) => p.valor),
    );
  });

  test('gera de 3 a 5 itens, do mais recente para o mais antigo', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    for (final cliente in ['a', 'b', 'c', id]) {
      final compras = c.read(comprasMockProvider(cliente));
      final pagamentos = c.read(pagamentosMockProvider(cliente));
      expect(compras.length, inInclusiveRange(3, 5));
      expect(pagamentos.length, inInclusiveRange(3, 5));
      for (var i = 1; i < compras.length; i++) {
        expect(compras[i].data.isBefore(compras[i - 1].data), isTrue);
      }
      for (var i = 1; i < pagamentos.length; i++) {
        expect(pagamentos[i].data.isBefore(pagamentos[i - 1].data), isTrue);
      }
    }
  });

  test('clientes diferentes recebem históricos diferentes', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(notas(c, id), isNot(notas(c, 'outro-cliente')));
  });
}
