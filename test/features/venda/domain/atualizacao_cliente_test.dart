import 'package:cesta_basica_lopez_mobile/features/venda/domain/atualizacao_cliente.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/calculo_parcelas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime(2026, 11, 9, 10);
  final parcelas = gerarParcelas(
    vendaId: 'v1',
    total: 100,
    quantidade: 3,
    primeiroVencimento: DateTime(2026, 12, 9),
  );

  test('venda à vista só atualiza a última compra', () {
    final a = atualizacaoClienteDaVenda(
      clienteId: 'c1',
      agora: agora,
      parcelas: const [],
      valorEmAbertoAtual: 50,
      proximoVencimentoAtual: DateTime(2026, 11, 20),
    );
    expect(a.ultimaCompra, agora);
    expect(a.acrescimoEmAberto, 0);
    expect(a.proximoVencimento, isNull);
  });

  test('parcelada soma as parcelas e usa o 1º vencimento', () {
    final a = atualizacaoClienteDaVenda(
      clienteId: 'c1',
      agora: agora,
      parcelas: parcelas,
      valorEmAbertoAtual: 0,
      proximoVencimentoAtual: null,
    );
    expect(a.acrescimoEmAberto, 100);
    expect(a.proximoVencimento, DateTime(2026, 12, 9));
  });

  test('mantém o vencimento anterior se for mais cedo e há débito', () {
    final a = atualizacaoClienteDaVenda(
      clienteId: 'c1',
      agora: agora,
      parcelas: parcelas,
      valorEmAbertoAtual: 80,
      proximoVencimentoAtual: DateTime(2026, 11, 20),
    );
    expect(a.proximoVencimento, DateTime(2026, 11, 20));
  });

  test('ignora vencimento antigo quando o cliente não deve nada', () {
    final a = atualizacaoClienteDaVenda(
      clienteId: 'c1',
      agora: agora,
      parcelas: parcelas,
      valorEmAbertoAtual: 0,
      proximoVencimentoAtual: DateTime(2026, 1, 1),
    );
    expect(a.proximoVencimento, DateTime(2026, 12, 9));
  });
}
