import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/pos_venda_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 10, 16);

ParcelaModel _parcela(int n) => ParcelaModel(
  id: 'p$n',
  vendaId: 'v1',
  numero: n,
  valor: 50,
  vencimento: DateTime(2026, 12, n),
  updatedAt: _agora,
);

class _RepositorioFalso implements VendaRepository {
  _RepositorioFalso(this.origem, {this.cache = const []});

  final Stream<List<ParcelaModel>> origem;
  final List<ParcelaModel> cache;

  @override
  Stream<List<ParcelaModel>> observarParcelas(String vendaId) => origem;

  @override
  Future<List<ParcelaModel>> parcelasEmCache(String vendaId) async => cache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_RepositorioFalso repo) {
  final c = ProviderContainer(
    overrides: [vendaRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('comFallbackDeCache', () {
    test('stream que não emite cai no cache depois da espera', () {
      fakeAsync((async) {
        final origem = StreamController<List<int>>();
        final recebido = <List<int>>[];
        comFallbackDeCache<int>(
          origem.stream,
          () async => [1, 2],
          espera: const Duration(seconds: 2),
        ).listen(recebido.add);

        async.elapse(const Duration(seconds: 1));
        expect(recebido, isEmpty);
        async.elapse(const Duration(seconds: 2));
        expect(recebido, [
          [1, 2],
        ]);

        origem.add([1, 2, 3]);
        async.flushMicrotasks();
        expect(recebido.last, [1, 2, 3]);
      });
    });

    test('cache vazio vira TimeoutException', () {
      fakeAsync((async) {
        Object? erro;
        comFallbackDeCache<int>(
          StreamController<List<int>>().stream,
          () async => [],
          espera: const Duration(seconds: 2),
        ).listen((_) {}, onError: (Object e) => erro = e);

        async.elapse(const Duration(seconds: 3));
        expect(erro, isA<TimeoutException>());
      });
    });

    test('emissão da origem antes da espera não usa o cache', () async {
      var leuCache = false;
      final lista = await comFallbackDeCache<int>(Stream.value([7]), () async {
        leuCache = true;
        return [9];
      }, espera: const Duration(milliseconds: 20)).first;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(lista, [7]);
      expect(leuCache, isFalse);
    });
  });

  group('parcelasDaVendaProvider', () {
    test('erro do stream vira AsyncError, sem ficar em loading', () async {
      final c = _container(
        _RepositorioFalso(Stream.error(StateError('failed-precondition'))),
      );
      final sub = c.listen(parcelasDaVendaProvider('v1'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estado = c.read(parcelasDaVendaProvider('v1'));
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
      sub.close();
    });

    test('stream sem emissão cai no cache em vez de ficar em loading', () {
      fakeAsync((async) {
        final c = _container(
          _RepositorioFalso(
            StreamController<List<ParcelaModel>>().stream,
            cache: [_parcela(1), _parcela(2)],
          ),
        );
        final sub = c.listen(parcelasDaVendaProvider('v1'), (_, _) {});

        async.elapse(const Duration(seconds: 1));
        expect(c.read(parcelasDaVendaProvider('v1')).isLoading, isTrue);

        async.elapse(esperaParcelasAntesDoCache);
        async.flushMicrotasks();
        final estado = c.read(parcelasDaVendaProvider('v1'));
        expect(estado.hasValue, isTrue);
        expect(estado.requireValue.map((p) => p.numero), [1, 2]);
        sub.close();
      });
    });

    test('sem emissão e sem cache vira erro', () {
      fakeAsync((async) {
        final c = _container(
          _RepositorioFalso(StreamController<List<ParcelaModel>>().stream),
        );
        final sub = c.listen(parcelasDaVendaProvider('v1'), (_, _) {});

        async.elapse(esperaParcelasAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(parcelasDaVendaProvider('v1')).hasError, isTrue);
        sub.close();
      });
    });
  });
}
