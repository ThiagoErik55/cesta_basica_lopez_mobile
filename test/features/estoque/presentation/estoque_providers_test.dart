import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/estoque_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/movimento_estoque_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 10);

ProdutoModel _produto(String id, int estoque) => ProdutoModel(
  id: id,
  codigo: 'P-$id',
  nome: 'Produto $id',
  marca: 'M',
  categoria: 'C',
  preco: 10,
  custoAtual: 5,
  estoqueAtual: estoque,
  updatedAt: _t,
);

MovimentoEstoqueModel _mov(String id, DateTime data) => MovimentoEstoqueModel(
  id: id,
  produtoId: 'a',
  tipo: TipoMovimento.saida,
  quantidade: 1,
  data: data,
  vendedorUid: 'u',
  updatedAt: _t,
);

class _ProdutosFalso implements ProdutoRepository {
  _ProdutosFalso(this.origem, {this.cache = const []});
  final Stream<List<ProdutoModel>> origem;
  final List<ProdutoModel> cache;

  @override
  Stream<List<ProdutoModel>> observarAtivos() => origem;

  @override
  Future<List<ProdutoModel>> ativosEmCache() async => cache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EstoqueFalso implements EstoqueRepository {
  _EstoqueFalso(this.origem, {this.cache = const []});
  final Stream<List<MovimentoEstoqueModel>> origem;
  final List<MovimentoEstoqueModel> cache;

  @override
  Stream<List<MovimentoEstoqueModel>> observarPorProduto(String produtoId) =>
      origem;

  @override
  Future<List<MovimentoEstoqueModel>> movimentosEmCache(
    String produtoId,
  ) async => cache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  _ProdutosFalso? produtos,
  _EstoqueFalso? estoque,
}) {
  final c = ProviderContainer(
    overrides: [
      if (produtos != null)
        produtoRepositoryProvider.overrideWithValue(produtos),
      if (estoque != null) estoqueRepositoryProvider.overrideWithValue(estoque),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('filtroEstoqueProvider', () {
    test('cada filtro preserva os outros', () {
      final c = _container();
      final n = c.read(filtroEstoqueProvider.notifier);
      c.listen(filtroEstoqueProvider, (_, _) {});

      n.buscar('arroz');
      n.filtrarPorSituacao(SituacaoEstoque.baixo);
      n.filtrarPorCategoria('Grãos');

      final f = c.read(filtroEstoqueProvider);
      expect(f.termo, 'arroz');
      expect(f.situacao, SituacaoEstoque.baixo);
      expect(f.categoria, 'Grãos');

      n.filtrarPorSituacao(null);
      expect(c.read(filtroEstoqueProvider).situacao, isNull);
      expect(c.read(filtroEstoqueProvider).termo, 'arroz');
    });
  });

  group('itensEstoqueProvider', () {
    test('emite os itens com situação derivada', () async {
      final c = _container(
        produtos: _ProdutosFalso(
          Stream.value([_produto('a', 0), _produto('b', 50)]),
        ),
      );
      c.listen(itensEstoqueProvider, (_, _) {});
      final itens = await c.read(itensEstoqueProvider.future);
      expect(itens.map((i) => i.situacao), [
        SituacaoEstoque.semEstoque,
        SituacaoEstoque.normal,
      ]);
    });

    test('erro do stream vira AsyncError, sem ficar em loading', () async {
      final c = _container(
        produtos: _ProdutosFalso(Stream.error(StateError('falhou'))),
      );
      final sub = c.listen(itensEstoqueProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estado = c.read(itensEstoqueProvider);
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
      sub.close();
    });

    test('stream sem emissão cai no cache em vez de ficar em loading', () {
      fakeAsync((async) {
        final c = _container(
          produtos: _ProdutosFalso(
            StreamController<List<ProdutoModel>>().stream,
            cache: [_produto('a', 3)],
          ),
        );
        final sub = c.listen(itensEstoqueProvider, (_, _) {});

        async.elapse(const Duration(seconds: 1));
        expect(c.read(itensEstoqueProvider).isLoading, isTrue);

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        final estado = c.read(itensEstoqueProvider);
        expect(estado.hasValue, isTrue);
        expect(estado.requireValue.single.situacao, SituacaoEstoque.baixo);
        sub.close();
      });
    });

    test('sem emissão e sem cache vira erro', () {
      fakeAsync((async) {
        final c = _container(
          produtos: _ProdutosFalso(
            StreamController<List<ProdutoModel>>().stream,
          ),
        );
        final sub = c.listen(itensEstoqueProvider, (_, _) {});

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(itensEstoqueProvider).hasError, isTrue);
        sub.close();
      });
    });
  });

  group('movimentosDoProdutoProvider', () {
    test('ordena do mais recente para o mais antigo', () async {
      final c = _container(
        estoque: _EstoqueFalso(
          Stream.value([
            _mov('velho', DateTime(2026, 11, 1)),
            _mov('novo', DateTime(2026, 11, 9)),
          ]),
        ),
      );
      c.listen(movimentosDoProdutoProvider('a'), (_, _) {});
      final r = await c.read(movimentosDoProdutoProvider('a').future);
      expect(r.map((m) => m.id), ['novo', 'velho']);
    });

    test('erro do stream vira AsyncError, sem ficar em loading', () async {
      final c = _container(
        estoque: _EstoqueFalso(Stream.error(StateError('falhou'))),
      );
      final sub = c.listen(movimentosDoProdutoProvider('a'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estado = c.read(movimentosDoProdutoProvider('a'));
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
      sub.close();
    });

    test('stream sem emissão cai no cache', () {
      fakeAsync((async) {
        final c = _container(
          estoque: _EstoqueFalso(
            StreamController<List<MovimentoEstoqueModel>>().stream,
            cache: [_mov('x', DateTime(2026, 11, 2))],
          ),
        );
        final sub = c.listen(movimentosDoProdutoProvider('a'), (_, _) {});

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        final estado = c.read(movimentosDoProdutoProvider('a'));
        expect(estado.hasValue, isTrue);
        expect(estado.requireValue.single.id, 'x');
        sub.close();
      });
    });
  });
}
