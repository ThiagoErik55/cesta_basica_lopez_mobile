import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/movimento_estoque_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 10);

ProdutoModel _p(
  String id,
  String nome, {
  int estoque = 20,
  int minimo = 10,
  double custo = 5,
  String marca = 'Marca',
  String categoria = 'Grãos',
  String codigo = 'P-1',
  bool deleted = false,
}) => ProdutoModel(
  id: id,
  codigo: codigo,
  nome: nome,
  marca: marca,
  categoria: categoria,
  preco: 10,
  custoAtual: custo,
  estoqueAtual: estoque,
  estoqueMinimo: minimo,
  updatedAt: _t,
  deleted: deleted,
);

List<ItemEstoque> _itens(List<ProdutoModel> ps) => montarItensEstoque(ps);

MovimentoEstoqueModel _m(String id, DateTime data, {bool deleted = false}) =>
    MovimentoEstoqueModel(
      id: id,
      produtoId: 'a',
      tipo: TipoMovimento.saida,
      quantidade: 1,
      data: data,
      vendedorUid: 'u',
      updatedAt: _t,
      deleted: deleted,
    );

void main() {
  group('situacaoDoEstoque', () {
    SituacaoEstoque s(int atual, int min) =>
        situacaoDoEstoque(estoqueAtual: atual, estoqueMinimo: min);

    test(
      'normal acima do mínimo',
      () => expect(s(11, 10), SituacaoEstoque.normal),
    );
    test(
      'baixo no limite do mínimo',
      () => expect(s(10, 10), SituacaoEstoque.baixo),
    );
    test(
      'baixo entre 1 e o mínimo',
      () => expect(s(1, 10), SituacaoEstoque.baixo),
    );
    test(
      'sem estoque em zero',
      () => expect(s(0, 10), SituacaoEstoque.semEstoque),
    );
    test('negativo conta como sem estoque', () {
      expect(s(-3, 10), SituacaoEstoque.semEstoque);
      expect(estoqueNegativo(-3), isTrue);
      expect(estoqueNegativo(0), isFalse);
    });
    test('mínimo 0: positivo é normal, zero é sem estoque', () {
      expect(s(1, 0), SituacaoEstoque.normal);
      expect(s(0, 0), SituacaoEstoque.semEstoque);
    });
  });

  group('calcularValorEmEstoque', () {
    test('estoque × custo sem erro de ponto flutuante', () {
      expect(calcularValorEmEstoque(estoqueAtual: 3, custoAtual: 0.1), 0.3);
      expect(calcularValorEmEstoque(estoqueAtual: 7, custoAtual: 12.35), 86.45);
    });
    test('saldo negativo dá valor negativo no item', () {
      expect(calcularValorEmEstoque(estoqueAtual: -2, custoAtual: 5), -10);
    });
  });

  test('montarItensEstoque ignora produtos removidos', () {
    final itens = _itens([_p('a', 'A'), _p('b', 'B', deleted: true)]);
    expect(itens.map((i) => i.produto.id), ['a']);
  });

  group('resumirEstoque', () {
    test('conta situações e soma o valor ignorando negativos', () {
      final r = resumirEstoque(
        _itens([
          _p('a', 'A', estoque: 20, custo: 5), // normal: 100
          _p('b', 'B', estoque: 4, custo: 2.5), // baixo: 10
          _p('c', 'C', estoque: 0), // sem estoque
          _p('d', 'D', estoque: -5, custo: 100), // negativo: não soma
        ]),
      );
      expect(r.totalProdutos, 4);
      expect(r.semEstoque, 2);
      expect(r.estoqueBaixo, 1);
      expect(r.valorTotal, 110);
    });

    test('lista vazia zera tudo', () {
      final r = resumirEstoque(const []);
      expect(r.totalProdutos, 0);
      expect(r.semEstoque, 0);
      expect(r.estoqueBaixo, 0);
      expect(r.valorTotal, 0);
    });
  });

  group('filtrarEstoque', () {
    final itens = _itens([
      _p('a', 'Açúcar Cristal', marca: 'União', codigo: 'P-AC1', estoque: 50),
      _p(
        'b',
        'Feijão',
        marca: 'Camil',
        codigo: 'P-FE2',
        estoque: 5,
        categoria: 'Grãos',
      ),
      _p(
        'c',
        'Óleo de Soja',
        marca: 'Liza',
        codigo: 'P-OL3',
        estoque: 0,
        categoria: 'Óleos',
      ),
    ]);

    test('busca por nome sem acento nem maiúsculas', () {
      expect(filtrarEstoque(itens, termo: 'ACUCAR').map((i) => i.produto.id), [
        'a',
      ]);
      expect(filtrarEstoque(itens, termo: 'oleo').map((i) => i.produto.id), [
        'c',
      ]);
      expect(filtrarEstoque(itens, termo: 'feijao').map((i) => i.produto.id), [
        'b',
      ]);
    });

    test('busca por marca e por código', () {
      expect(filtrarEstoque(itens, termo: 'uniao').map((i) => i.produto.id), [
        'a',
      ]);
      expect(filtrarEstoque(itens, termo: 'p-fe2').map((i) => i.produto.id), [
        'b',
      ]);
    });

    test('filtra por situação', () {
      expect(
        filtrarEstoque(
          itens,
          situacao: SituacaoEstoque.baixo,
        ).map((i) => i.produto.id),
        ['b'],
      );
      expect(
        filtrarEstoque(
          itens,
          situacao: SituacaoEstoque.semEstoque,
        ).map((i) => i.produto.id),
        ['c'],
      );
    });

    test('filtra por categoria e combina com a busca', () {
      expect(
        filtrarEstoque(itens, categoria: 'Óleos').map((i) => i.produto.id),
        ['c'],
      );
      expect(filtrarEstoque(itens, categoria: 'Grãos', termo: 'fei').length, 1);
      expect(filtrarEstoque(itens, categoria: 'Óleos', termo: 'fei'), isEmpty);
    });

    test('sem filtros devolve tudo; termo só com espaços não filtra', () {
      expect(filtrarEstoque(itens, termo: '  ').length, 3);
    });

    test('categoriasDoEstoque sem repetição e ordenadas', () {
      expect(categoriasDoEstoque(itens), ['Grãos', 'Óleos']);
    });
  });

  group('ordenarEstoque', () {
    test(
      'sem estoque, depois baixo, depois normal; por nome em cada grupo',
      () {
        final ordenados = ordenarEstoque(
          _itens([
            _p('1', 'Zeta', estoque: 50),
            _p('2', 'Ágata', estoque: 50),
            _p('3', 'Beta', estoque: 5),
            _p('4', 'Delta', estoque: 0),
            _p('5', 'Alfa', estoque: -1),
            _p('6', 'Alfa baixo', estoque: 2),
          ]),
        );
        expect(ordenados.map((i) => i.produto.nome), [
          'Alfa',
          'Delta',
          'Alfa baixo',
          'Beta',
          'Ágata',
          'Zeta',
        ]);
      },
    );

    test('não altera a lista original', () {
      final original = _itens([_p('1', 'B'), _p('2', 'A')]);
      ordenarEstoque(original);
      expect(original.first.produto.nome, 'B');
    });
  });

  group('ordenarMovimentos', () {
    test('do mais recente para o mais antigo, sem removidos', () {
      final r = ordenarMovimentos([
        _m('a', DateTime(2026, 11, 1)),
        _m('b', DateTime(2026, 11, 9)),
        _m('c', DateTime(2026, 11, 5), deleted: true),
        _m('d', DateTime(2026, 11, 3)),
      ]);
      expect(r.map((m) => m.id), ['b', 'd', 'a']);
    });
  });
}
