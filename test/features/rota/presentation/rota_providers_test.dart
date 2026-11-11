import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/associacao_rota.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/cadastro_rota.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 12);

RotaModel _rota(String id, String nome) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
);

ClienteModel _cliente(String id, String? rotaId) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: 'Cliente $id',
  cpf: '00000000000',
  telefone: '',
  endereco: '',
  rotaId: rotaId == '' ? null : rotaId,
  updatedAt: _t,
);

class _RepoFalso implements RotaRepository {
  _RepoFalso({
    this.rotas = const Stream.empty(),
    this.clientes = const Stream.empty(),
    this.rotasCache = const [],
    this.clientesCache = const [],
  });

  final Stream<List<RotaModel>> rotas;
  final Stream<List<ClienteModel>> clientes;
  final List<RotaModel> rotasCache;
  final List<ClienteModel> clientesCache;

  @override
  Stream<List<RotaModel>> observarAtivas() => rotas;

  @override
  Future<List<RotaModel>> ativasEmCache() async => rotasCache;

  @override
  Stream<List<ClienteModel>> observarClientesAtivos() => clientes;

  @override
  Future<List<ClienteModel>> clientesAtivosEmCache() async => clientesCache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(RotaRepository repo) {
  final c = ProviderContainer(
    overrides: [rotaRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('rotasAtivasProvider', () {
    test('emite as rotas', () async {
      final c = _container(
        _RepoFalso(rotas: Stream.value([_rota('1', 'Centro')])),
      );
      c.listen(rotasAtivasProvider, (_, _) {});
      final r = await c.read(rotasAtivasProvider.future);
      expect(r.single.nome, 'Centro');
    });

    test('erro do stream vira AsyncError, sem ficar em loading', () async {
      final c = _container(_RepoFalso(rotas: Stream.error(StateError('x'))));
      final sub = c.listen(rotasAtivasProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estado = c.read(rotasAtivasProvider);
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
      sub.close();
    });

    test('stream sem emissão cai no cache em vez de ficar em loading', () {
      fakeAsync((async) {
        final c = _container(
          _RepoFalso(
            rotas: StreamController<List<RotaModel>>().stream,
            rotasCache: [_rota('1', 'Centro')],
          ),
        );
        final sub = c.listen(rotasAtivasProvider, (_, _) {});

        async.elapse(const Duration(seconds: 1));
        expect(c.read(rotasAtivasProvider).isLoading, isTrue);

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(rotasAtivasProvider).requireValue.single.nome, 'Centro');
        sub.close();
      });
    });

    test('sem emissão e sem cache vira erro, não spinner infinito', () {
      fakeAsync((async) {
        final c = _container(
          _RepoFalso(rotas: StreamController<List<RotaModel>>().stream),
        );
        final sub = c.listen(rotasAtivasProvider, (_, _) {});

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(rotasAtivasProvider).hasError, isTrue);
        sub.close();
      });
    });
  });

  group('clientesDasRotasProvider', () {
    test('stream sem emissão cai no cache dos clientes', () {
      fakeAsync((async) {
        final c = _container(
          _RepoFalso(
            clientes: StreamController<List<ClienteModel>>().stream,
            clientesCache: [_cliente('a', '1')],
          ),
        );
        final sub = c.listen(clientesDasRotasProvider, (_, _) {});

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(clientesDasRotasProvider).requireValue, hasLength(1));
        sub.close();
      });
    });

    test('erro vira AsyncError, sem ficar em loading', () async {
      final c = _container(_RepoFalso(clientes: Stream.error(StateError('x'))));
      final sub = c.listen(clientesDasRotasProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final estado = c.read(clientesDasRotasProvider);
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
      sub.close();
    });
  });

  group('itensRotaProvider', () {
    test('junta rotas e contagem de clientes', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('1', 'Centro'), _rota('2', 'Sul')]),
          clientes: Stream.value([
            _cliente('a', '1'),
            _cliente('b', '1'),
            _cliente('c', '2'),
          ]),
        ),
      );
      c.listen(itensRotaProvider, (_, _) {});
      c.listen(clientesDasRotasProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      final itens = c.read(itensRotaProvider).requireValue;
      expect(
        [for (final i in itens) (i.rota.nome, i.clientes)],
        [('Centro', 2), ('Sul', 1)],
      );
    });

    test(
      'clientes com erro: as rotas aparecem com contagem desconhecida',
      () async {
        final c = _container(
          _RepoFalso(
            rotas: Stream.value([_rota('1', 'Centro')]),
            clientes: Stream.error(StateError('x')),
          ),
        );
        c.listen(itensRotaProvider, (_, _) {});
        c.listen(clientesDasRotasProvider, (_, _) {});
        await c.read(rotasAtivasProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final itens = c.read(itensRotaProvider).requireValue;
        expect(itens.single.clientes, isNull);
      },
    );

    test('rotas com erro: o estado é de erro, sem loading', () async {
      final c = _container(_RepoFalso(rotas: Stream.error(StateError('x'))));
      c.listen(itensRotaProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final estado = c.read(itensRotaProvider);
      expect(estado.hasError, isTrue);
      expect(estado.isLoading, isFalse);
    });
  });

  group('SalvarRotaNotifier (com Firestore falso)', () {
    late FakeFirebaseFirestore db;
    late ProviderContainer c;

    setUp(() async {
      db = FakeFirebaseFirestore();
      c = _container(RotaRepository(db));
      await db.collection('rotas').doc('r1').set(_rota('r1', 'Centro').toMap());
      // Mantém os streams escutados (autoDispose) e já carregados.
      c.listen(itensRotaProvider, (_, _) {});
      c.listen(clientesDasRotasProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);
    });

    Future<Map<String, dynamic>?> doc(String id) async =>
        (await db.collection('rotas').doc(id).get()).data();

    test('cadastrar cria com id e código gerados, nome limpo', () async {
      final sincronizado = await c
          .read(salvarRotaProvider.notifier)
          .cadastrar(
            const DadosCadastraisRota(
              nome: '  Zona   Sul ',
              linha: LinhaAtendimento.regional,
            ),
          );
      expect(sincronizado, isTrue);

      final docs = (await db.collection('rotas').get()).docs;
      final nova = docs.firstWhere((d) => d.id != 'r1').data();
      expect(nova['nome'], 'Zona Sul');
      expect(nova['linhaAtendimento'], 'regional');
      expect(nova['id'], isNotEmpty);
      expect(nova['codigo'], startsWith('R-'));
      expect(nova['deleted'], false);
    });

    test('cadastrar nome duplicado (acento/caixa) lança e não grava', () async {
      await expectLater(
        c
            .read(salvarRotaProvider.notifier)
            .cadastrar(
              const DadosCadastraisRota(
                nome: 'CENTRO',
                linha: LinhaAtendimento.toledo,
              ),
            ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Já existe uma rota com esse nome.',
          ),
        ),
      );
      expect((await db.collection('rotas').get()).docs, hasLength(1));
    });

    test('atualizar grava só o que mudou', () async {
      final original = _rota('r1', 'Centro');
      await c
          .read(salvarRotaProvider.notifier)
          .atualizar(
            original,
            const DadosCadastraisRota(
              nome: 'Centro Novo',
              linha: LinhaAtendimento.toledo,
            ),
          );
      final d = (await doc('r1'))!;
      expect(d['nome'], 'Centro Novo');
      expect(d['linhaAtendimento'], 'toledo');
      expect(d['updatedAt'], isNot(_t.toIso8601String()));
    });

    test('atualizar sem mudança não escreve nada', () async {
      final antes = await doc('r1');
      await c
          .read(salvarRotaProvider.notifier)
          .atualizar(
            _rota('r1', 'Centro'),
            const DadosCadastraisRota(
              nome: 'Centro',
              linha: LinhaAtendimento.toledo,
            ),
          );
      expect(await doc('r1'), antes);
    });

    test('atualizar com o próprio nome em outra caixa é permitido', () async {
      await c
          .read(salvarRotaProvider.notifier)
          .atualizar(
            _rota('r1', 'Centro'),
            const DadosCadastraisRota(
              nome: 'CENTRO',
              linha: LinhaAtendimento.toledo,
            ),
          );
      expect((await doc('r1'))!['nome'], 'CENTRO');
    });

    test('excluir rota sem clientes faz exclusão lógica', () async {
      await c.read(salvarRotaProvider.notifier).excluir('r1');
      expect((await doc('r1'))!['deleted'], true);
    });

    test('excluir rota com clientes é bloqueado e não grava', () async {
      await db
          .collection('clientes')
          .doc('c1')
          .set(_cliente('c1', 'r1').toMap());
      await db
          .collection('clientes')
          .doc('c2')
          .set(_cliente('c2', 'r1').toMap());
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        c.read(salvarRotaProvider.notifier).excluir('r1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Remova ou mude os 2 clientes desta rota antes de excluir.',
          ),
        ),
      );
      expect((await doc('r1'))!['deleted'], false);
    });
  });

  _grupoAssociacao();
}

void _grupoAssociacao() {
  group('AssociarClientesNotifier (com Firestore falso)', () {
    late FakeFirebaseFirestore db;
    late ProviderContainer c;

    setUp(() async {
      db = FakeFirebaseFirestore();
      c = _container(RotaRepository(db));
      await db.collection('rotas').doc('a').set(_rota('a', 'Centro').toMap());
      for (final id in ['1', '2', '3']) {
        await db.collection('clientes').doc(id).set(_cliente(id, '').toMap());
      }
      c.listen(rotasAtivasProvider, (_, _) {});
      c.listen(clientesDasRotasProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);
    });

    Future<Map<String, dynamic>> doc(String id) async =>
        (await db.collection('clientes').doc(id).get()).data()!;

    test('aplica o diff: grava só os que mudaram', () async {
      final antes3 = await doc('3');
      final sincronizado = await c
          .read(associarClientesProvider.notifier)
          .aplicar('a', const DiffAssociacao(adicionados: ['1', '2']));

      expect(sincronizado, isTrue);
      expect((await doc('1'))['rotaId'], 'a');
      expect((await doc('2'))['rotaId'], 'a');
      expect(await doc('3'), antes3);
    });

    test('sem mudanças não grava', () async {
      final antes = await doc('1');
      await c
          .read(associarClientesProvider.notifier)
          .aplicar('a', const DiffAssociacao(inalterados: ['1']));
      expect(await doc('1'), antes);
    });

    test('rota excluída ou inexistente é recusada, sem gravar', () async {
      await expectLater(
        c
            .read(associarClientesProvider.notifier)
            .aplicar('fantasma', const DiffAssociacao(adicionados: ['1'])),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Esta rota não existe mais.',
          ),
        ),
      );
      expect((await doc('1'))['rotaId'], anyOf(isNull, ''));
    });

    test('definirRotaDoCliente troca e limpa a rota de um cliente', () async {
      final n = c.read(associarClientesProvider.notifier);
      await n.definirRotaDoCliente('1', 'a');
      expect((await doc('1'))['rotaId'], 'a');
      await n.definirRotaDoCliente('1', null);
      expect((await doc('1'))['rotaId'], isNull);
    });
  });
}
