import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/entrada_estoque.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 11, 15, 30, 10);

ResultadoEntrada _avaliar({
  String quantidade = '10',
  double? custo = 5,
  DateTime? data,
  int estoque = 20,
  double custoAtual = 4,
}) => avaliarEntrada(
  quantidade: quantidade,
  custo: custo,
  data: data ?? _agora,
  agora: _agora,
  estoqueAtual: estoque,
  custoAtual: custoAtual,
);

void main() {
  group('lerQuantidadeInteira', () {
    test('aceita inteiro positivo', () {
      expect(lerQuantidadeInteira('10'), 10);
      expect(lerQuantidadeInteira(' 7 '), 7);
      expect(lerQuantidadeInteira('0'), 0);
    });
    test('rejeita vazio, decimal, negativo e texto', () {
      for (final t in ['', ' ', '1,5', '1.5', '-3', 'abc', '1e3', '+2']) {
        expect(lerQuantidadeInteira(t), isNull, reason: t);
      }
    });
  });

  group('quantidade', () {
    test('válida', () {
      final r = _avaliar(quantidade: '10');
      expect(r.erroQuantidade, isNull);
      expect(r.quantidade, 10);
    });
    test('vazia', () {
      expect(_avaliar(quantidade: '').erroQuantidade, 'Informe a quantidade.');
    });
    test('zero', () {
      expect(
        _avaliar(quantidade: '0').erroQuantidade,
        'A quantidade deve ser maior que zero.',
      );
    });
    test('negativa e decimal não são inteiros', () {
      const msg = 'A quantidade deve ser um número inteiro.';
      expect(_avaliar(quantidade: '-5').erroQuantidade, msg);
      expect(_avaliar(quantidade: '2,5').erroQuantidade, msg);
    });
    test('inválida não gera prévia de estoque', () {
      final r = _avaliar(quantidade: '0');
      expect(r.quantidade, isNull);
      expect(r.estoqueApos, isNull);
    });
  });

  group('custo unitário', () {
    test('válido', () => expect(_avaliar(custo: 0.01).erroCusto, isNull));
    test('não informado', () {
      expect(_avaliar(custo: null).erroCusto, 'Informe o custo unitário.');
    });
    test('zero e negativo', () {
      const msg = 'O custo unitário deve ser maior que zero.';
      expect(_avaliar(custo: 0).erroCusto, msg);
      expect(_avaliar(custo: -1).erroCusto, msg);
    });
    test('inválido não gera novo custo', () {
      expect(_avaliar(custo: 0).novoCusto, isNull);
    });
  });

  group('data', () {
    test('hoje e passado são válidos', () {
      expect(_avaliar(data: _agora).erroData, isNull);
      expect(_avaliar(data: DateTime(2026, 11, 1)).erroData, isNull);
    });
    test('hoje à noite não é futuro mesmo com hora maior', () {
      expect(_avaliar(data: DateTime(2026, 11, 11, 23, 59)).erroData, isNull);
    });
    test('amanhã é futuro', () {
      expect(
        _avaliar(data: DateTime(2026, 11, 12)).erroData,
        'A data da entrada não pode ser futura.',
      );
    });
  });

  group('prévia', () {
    test('estoque após e novo custo (custo da última compra)', () {
      final r = _avaliar(quantidade: '10', custo: 5.5, estoque: 20);
      expect(r.estoqueApos, 30);
      expect(r.novoCusto, 5.5);
      expect(r.custoAtual, 4);
      expect(r.ok, isTrue);
    });

    test('não calcula custo médio: o novo custo é o informado', () {
      final r = _avaliar(
        quantidade: '100',
        custo: 2,
        estoque: 900,
        custoAtual: 10,
      );
      expect(r.novoCusto, 2);
    });

    test('entrada sobre saldo negativo soma normalmente', () {
      final r = _avaliar(quantidade: '10', estoque: -4);
      expect(r.saldoNegativoAntes, isTrue);
      expect(r.estoqueApos, 6);
    });

    test('estoque zerado', () {
      final r = _avaliar(quantidade: '3', estoque: 0);
      expect(r.saldoNegativoAntes, isFalse);
      expect(r.estoqueApos, 3);
    });

    test('ok é falso com qualquer erro', () {
      expect(_avaliar(quantidade: '0').ok, isFalse);
      expect(_avaliar(custo: null).ok, isFalse);
      expect(_avaliar(data: DateTime(2026, 12, 1)).ok, isFalse);
    });
  });

  group('montarMovimentoEntrada', () {
    test('monta a entrada com custo, data e observação aparada', () {
      final m = montarMovimentoEntrada(
        id: 'm1',
        produtoId: 'p1',
        quantidade: 12,
        custoUnitario: 4.2,
        data: DateTime(2026, 11, 3),
        vendedorUid: 'u1',
        observacao: '  Fornecedor X  ',
        agora: _agora,
      );
      expect(m.tipo, TipoMovimento.entrada);
      expect(m.quantidade, 12);
      expect(m.custoUnitario, 4.2);
      expect(m.delta, 12);
      expect(m.observacao, 'Fornecedor X');
      expect(m.vendaId, isNull);
      expect(m.data, DateTime(2026, 11, 3, 15, 30, 10));
    });

    test('observação em branco vira null e não vai no mapa', () {
      final m = montarMovimentoEntrada(
        id: 'm1',
        produtoId: 'p1',
        quantidade: 1,
        custoUnitario: 1,
        data: _agora,
        vendedorUid: 'u1',
        observacao: '   ',
        agora: _agora,
      );
      expect(m.observacao, isNull);
      expect(m.toMap().containsKey('observacao'), isFalse);
    });

    test('data de hoje não fica no futuro', () {
      final m = montarMovimentoEntrada(
        id: 'm',
        produtoId: 'p',
        quantidade: 1,
        custoUnitario: 1,
        data: DateTime(2026, 11, 11),
        vendedorUid: 'u',
        agora: _agora,
      );
      expect(m.data.isAfter(_agora), isFalse);
    });
  });
}
