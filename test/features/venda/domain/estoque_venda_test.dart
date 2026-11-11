import 'package:cesta_basica_lopez_mobile/features/estoque/domain/regra_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/carrinho.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/estoque_venda.dart';
import 'package:flutter_test/flutter_test.dart';

ProdutoModel _p(String id, int estoque, {String? nome}) => ProdutoModel(
  id: id,
  codigo: 'P-$id',
  nome: nome ?? 'Produto $id',
  marca: 'M',
  categoria: 'C',
  preco: 10,
  estoqueAtual: estoque,
  updatedAt: DateTime(2026, 11, 11),
);

ItemCarrinho _i(String id, int estoque, int qtd) =>
    ItemCarrinho(produto: _p(id, estoque), quantidade: qtd);

const _bloqueia = RegraEstoque(bloquearVendaSemEstoque: true);
const _permite = RegraEstoque(bloquearVendaSemEstoque: false);

void main() {
  test('o padrão da regra é não bloquear', () {
    expect(padraoBloquearVendaSemEstoque, isFalse);
    expect(regraEstoquePadrao.bloquearVendaSemEstoque, isFalse);
    expect(const RegraEstoque(), regraEstoquePadrao);
  });

  test('copyWith e igualdade da regra', () {
    final r = regraEstoquePadrao.copyWith(bloquearVendaSemEstoque: true);
    expect(r, _bloqueia);
    expect(r.hashCode, _bloqueia.hashCode);
    expect(r.copyWith(), r);
  });

  group('somarQuantidadesPorProduto', () {
    test('soma linhas repetidas do mesmo produto', () {
      final soma = somarQuantidadesPorProduto([
        _i('a', 10, 2),
        _i('b', 10, 3),
        _i('a', 10, 4),
      ]);
      expect(soma, {'a': 6, 'b': 3});
    });
    test('carrinho vazio', () {
      expect(somarQuantidadesPorProduto(const []), isEmpty);
    });
  });

  group('itensAcimaDoEstoque', () {
    test('quantidade igual ao estoque é permitida', () {
      expect(itensAcimaDoEstoque([_i('a', 5, 5)]), isEmpty);
    });
    test('uma unidade acima do estoque', () {
      final r = itensAcimaDoEstoque([_i('a', 5, 6)]);
      expect(r.single.faltam, 1);
      expect(r.single.estoque, 5);
      expect(r.single.quantidade, 6);
    });
    test('estoque zero: faltam todas as pedidas', () {
      final r = itensAcimaDoEstoque([_i('a', 0, 3)]);
      expect(r.single.faltam, 3);
    });
    test('estoque negativo: faltam todas as pedidas, não mais', () {
      final r = itensAcimaDoEstoque([_i('a', -4, 3)]);
      expect(r.single.faltam, 3);
      expect(r.single.estoque, -4);
    });
    test('linhas repetidas somam antes de comparar, sem item duplicado', () {
      final r = itensAcimaDoEstoque([_i('a', 5, 3), _i('a', 5, 3)]);
      expect(r.length, 1);
      expect(r.single.quantidade, 6);
      expect(r.single.faltam, 1);
    });
    test('só os produtos acima do estoque, na ordem do carrinho', () {
      final r = itensAcimaDoEstoque([
        _i('a', 10, 2),
        _i('b', 1, 2),
        _i('c', 0, 1),
      ]);
      expect(r.map((e) => e.produtoId), ['b', 'c']);
    });
  });

  group('mensagens', () {
    test('texto abaixo do item', () {
      final item = itensAcimaDoEstoque([_i('a', 3, 5)]).single;
      expect(textoFaltaEstoque(item), 'Estoque: 3 · faltam 2');
    });
    test('texto com estoque negativo mostra o saldo', () {
      final item = itensAcimaDoEstoque([_i('a', -2, 1)]).single;
      expect(textoFaltaEstoque(item), 'Estoque: -2 · faltam 1');
    });
    test('mensagem de bloqueio por produto', () {
      final item = itensAcimaDoEstoque([
        ItemCarrinho(produto: _p('a', 3, nome: 'Arroz'), quantidade: 5),
      ]).single;
      expect(
        mensagemBloqueioEstoque(item),
        'Arroz: pedido 5, estoque 3 (faltam 2).',
      );
    });
  });

  group('impedimentosDeEstoque', () {
    final acima = [_i('a', 3, 5), _i('b', 0, 1), _i('c', 9, 9)];

    test('bloqueio ligado: uma mensagem por produto acima do estoque', () {
      final r = impedimentosDeEstoque(acima, _bloqueia);
      expect(r.length, 2);
      expect(r[0], contains('Produto a'));
      expect(r[1], contains('Produto b'));
    });
    test('bloqueio desligado: nada impede', () {
      expect(impedimentosDeEstoque(acima, _permite), isEmpty);
    });
    test('bloqueio ligado, estoque igual à quantidade: permitido', () {
      expect(impedimentosDeEstoque([_i('a', 5, 5)], _bloqueia), isEmpty);
    });
    test('bloqueio ligado, estoque 0 e negativo: bloqueia', () {
      expect(impedimentosDeEstoque([_i('a', 0, 1)], _bloqueia).length, 1);
      expect(impedimentosDeEstoque([_i('a', -1, 1)], _bloqueia).length, 1);
    });
  });

  group('avisoResumoEstoque', () {
    test('um item', () {
      expect(
        avisoResumoEstoque([_i('a', 1, 2)], _permite),
        '1 item acima do estoque registrado: o estoque ficará negativo.',
      );
    });
    test('vários itens num aviso só', () {
      expect(
        avisoResumoEstoque([_i('a', 1, 2), _i('b', 0, 1)], _permite),
        '2 itens acima do estoque registrado: o estoque ficará negativo.',
      );
    });
    test('sem itens acima do estoque, sem aviso', () {
      expect(avisoResumoEstoque([_i('a', 5, 5)], _permite), isNull);
    });
    test('com bloqueio ligado não repete o aviso (vale o impedimento)', () {
      expect(avisoResumoEstoque([_i('a', 1, 2)], _bloqueia), isNull);
    });
  });
}
