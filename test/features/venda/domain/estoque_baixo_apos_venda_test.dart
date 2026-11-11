import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/carrinho.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/estoque_venda.dart';
import 'package:flutter_test/flutter_test.dart';

ItemCarrinho _i(
  String id,
  int estoque,
  int qtd, {
  int minimo = 10,
  String? nome,
}) => ItemCarrinho(
  produto: ProdutoModel(
    id: id,
    codigo: 'P-$id',
    nome: nome ?? 'Produto $id',
    marca: 'M',
    categoria: 'C',
    preco: 10,
    estoqueAtual: estoque,
    estoqueMinimo: minimo,
    updatedAt: DateTime(2026, 11, 11),
  ),
  quantidade: qtd,
);

void main() {
  group('itensComEstoqueBaixoAposVenda', () {
    test('produto que cai abaixo do mínimo é avisado, com o saldo final', () {
      final avisos = itensComEstoqueBaixoAposVenda([
        _i('a', 20, 17, nome: 'Arroz'),
      ]);
      expect(avisos.single.nome, 'Arroz');
      expect(avisos.single.estoqueApos, 3);
      expect(avisos.single.situacao, SituacaoEstoque.baixo);
    });

    test('continua normal depois da venda: sem aviso', () {
      expect(itensComEstoqueBaixoAposVenda([_i('a', 50, 5)]), isEmpty);
    });

    test('saldo exatamente igual ao mínimo é baixo (regra da KAN-41)', () {
      final avisos = itensComEstoqueBaixoAposVenda([_i('a', 15, 5)]);
      expect(avisos.single.estoqueApos, 10);
      expect(avisos.single.situacao, SituacaoEstoque.baixo);
    });

    test('um acima do mínimo ainda é normal', () {
      expect(itensComEstoqueBaixoAposVenda([_i('a', 16, 5)]), isEmpty);
    });

    test('já estava baixo e continua baixo: avisa', () {
      final avisos = itensComEstoqueBaixoAposVenda([_i('a', 8, 2)]);
      expect(avisos.single.estoqueApos, 6);
    });

    test('vende tudo: fica sem estoque (zero), não negativo', () {
      final avisos = itensComEstoqueBaixoAposVenda([_i('a', 4, 4)]);
      expect(avisos.single.estoqueApos, 0);
      expect(avisos.single.situacao, SituacaoEstoque.semEstoque);
    });

    test('ficaria negativo: já tem o aviso de "acima do estoque"', () {
      final itens = [_i('a', 3, 5)];
      expect(itensComEstoqueBaixoAposVenda(itens), isEmpty);
      expect(itensAcimaDoEstoque(itens), hasLength(1));
    });

    test('mínimo 0 nunca fica em baixo; só avisa ao zerar', () {
      expect(
        itensComEstoqueBaixoAposVenda([_i('a', 5, 4, minimo: 0)]),
        isEmpty,
      );
      final zerou = itensComEstoqueBaixoAposVenda([_i('a', 5, 5, minimo: 0)]);
      expect(zerou.single.situacao, SituacaoEstoque.semEstoque);
    });

    test('mesmo produto em duas linhas soma antes de avaliar, um aviso só', () {
      final avisos = itensComEstoqueBaixoAposVenda([
        _i('a', 20, 6),
        _i('a', 20, 6),
      ]);
      expect(avisos, hasLength(1));
      expect(avisos.single.estoqueApos, 8);
    });

    test('vários produtos mantêm a ordem do carrinho', () {
      final avisos = itensComEstoqueBaixoAposVenda([
        _i('b', 12, 5, nome: 'Feijão'),
        _i('c', 100, 1),
        _i('a', 9, 1, nome: 'Arroz'),
      ]);
      expect([for (final a in avisos) a.nome], ['Feijão', 'Arroz']);
    });

    test('carrinho vazio: nenhum aviso', () {
      expect(itensComEstoqueBaixoAposVenda(const []), isEmpty);
    });
  });

  group('textos', () {
    test('estoque baixo traz o saldo; zerado diz sem estoque', () {
      expect(
        avisosEstoqueBaixoAposVenda([
          _i('a', 20, 17, nome: 'Arroz'),
          _i('b', 4, 4, nome: 'Feijão'),
        ]),
        ['Arroz ficará com estoque baixo (3 un.)', 'Feijão ficará sem estoque'],
      );
    });
  });
}
