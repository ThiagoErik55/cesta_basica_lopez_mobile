import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/agenda_vendedor.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/agenda_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/controle_promissorias.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/promissorias_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);

RotaModel _rota(String id, String nome) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
);

ClienteModel _c(String id, String nome, {String? rotaId}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '52998224725',
  telefone: '',
  endereco: '',
  rotaId: rotaId,
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

ProviderContainer _container(
  RotaRepository repo, {
  DateTime? agora,
  AsyncValue<List<ItemPromissoria>> parcelas = const AsyncValue.data([]),
}) {
  final c = ProviderContainer(
    overrides: [
      rotaRepositoryProvider.overrideWithValue(repo),
      agendaRelogioProvider.overrideWithValue(
        () => agora ?? DateTime(2026, 11, 14, 9, 30),
      ),
      promissoriasProvider.overrideWith((ref, id) => parcelas),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('selecaoAgendaProvider', () {
    test('começa em hoje (sem hora), todas as rotas e filtro todos', () {
      final c = _container(_RepoFalso());
      c.listen(selecaoAgendaProvider, (_, _) {});
      final s = c.read(selecaoAgendaProvider);
      expect(s.data, DateTime(2026, 11, 14));
      expect(s.rotaId, isNull);
      expect(s.filtro, FiltroAgenda.todos);
      expect(s.termo, '');
      expect(c.read(selecaoAgendaProvider.notifier).hoje, isTrue);
    });

    test('dia anterior e próximo atravessam mês e ano', () {
      final c = _container(_RepoFalso(), agora: DateTime(2026, 12, 31, 23, 59));
      c.listen(selecaoAgendaProvider, (_, _) {});
      final n = c.read(selecaoAgendaProvider.notifier);

      n.proximoDia();
      expect(c.read(selecaoAgendaProvider).data, DateTime(2027, 1, 1));
      expect(n.hoje, isFalse);
      n.diaAnterior();
      n.diaAnterior();
      expect(c.read(selecaoAgendaProvider).data, DateTime(2026, 12, 30));
      n.irParaHoje();
      expect(c.read(selecaoAgendaProvider).data, DateTime(2026, 12, 31));
      expect(n.hoje, isTrue);
    });

    test('escolher data descarta a hora', () {
      final c = _container(_RepoFalso());
      c.listen(selecaoAgendaProvider, (_, _) {});
      c
          .read(selecaoAgendaProvider.notifier)
          .escolherData(DateTime(2026, 11, 20, 23, 59));
      expect(c.read(selecaoAgendaProvider).data, DateTime(2026, 11, 20));
    });

    test('rota, filtro e busca se combinam sem se apagar', () {
      final c = _container(_RepoFalso());
      c.listen(selecaoAgendaProvider, (_, _) {});
      final n = c.read(selecaoAgendaProvider.notifier);

      n.escolherRota('a');
      n.filtrar(FiltroAgenda.aCobrar);
      n.buscar('  ana ');
      n.proximoDia();
      var s = c.read(selecaoAgendaProvider);
      expect(s.rotaId, 'a');
      expect(s.filtro, FiltroAgenda.aCobrar);
      expect(s.termo, 'ana');
      expect(s.data, DateTime(2026, 11, 15));

      n.escolherRota(null);
      s = c.read(selecaoAgendaProvider);
      expect(s.rotaId, isNull);
      expect(s.filtro, FiltroAgenda.aCobrar);
    });
  });

  group('agendaProvider', () {
    test('monta a agenda com rotas, clientes e parcelas', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.value([
            _c('1', 'Ana', rotaId: 'a'),
            _c('2', 'Beto'),
          ]),
        ),
      );
      c.listen(agendaProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      final a = c.read(agendaProvider).requireValue;
      expect(a.itens.map((i) => i.cliente.nome), ['Ana', 'Beto']);
      expect(a.resumo.totalClientes, 2);
      expect(a.parcelasDisponiveis, isTrue);
    });

    test('escolher a rota restringe os clientes', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.value([
            _c('1', 'Ana', rotaId: 'a'),
            _c('2', 'Beto'),
          ]),
        ),
      );
      c.listen(agendaProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      c.read(selecaoAgendaProvider.notifier).escolherRota('a');
      final a = c.read(agendaProvider).requireValue;
      expect(a.itens.map((i) => i.cliente.nome), ['Ana']);
      expect(a.rotaId, 'a');
    });

    test('rota escolhida que foi excluída volta para todas as rotas', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.value([
            _c('1', 'Ana', rotaId: 'a'),
            _c('2', 'Beto'),
          ]),
        ),
      );
      c.listen(agendaProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      c.read(selecaoAgendaProvider.notifier).escolherRota('excluida');
      final a = c.read(agendaProvider).requireValue;
      expect(a.rotaId, isNull);
      expect(a.itens, hasLength(2));
    });

    test(
      'parcelas carregando: agenda sai, marcada como sem parcelas',
      () async {
        final c = _container(
          _RepoFalso(
            rotas: Stream.value([_rota('a', 'Centro')]),
            clientes: Stream.value([_c('1', 'Ana')]),
          ),
          parcelas: const AsyncValue.loading(),
        );
        c.listen(agendaProvider, (_, _) {});
        await c.read(rotasAtivasProvider.future);
        await c.read(clientesDasRotasProvider.future);

        final a = c.read(agendaProvider).requireValue;
        expect(a.parcelasDisponiveis, isFalse);
        expect(a.resumo.valoresExatos, isFalse);
      },
    );

    test('parcelas com erro: agenda sai, sem derrubar a tela', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.value([_c('1', 'Ana')]),
        ),
        parcelas: AsyncValue.error(StateError('x'), StackTrace.empty),
      );
      c.listen(agendaProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);
      expect(c.read(agendaProvider).requireValue.parcelasDisponiveis, isFalse);
    });

    test('as parcelas entram no resumo quando disponíveis', () async {
      final venda = VendaModel(
        id: 'v',
        clienteId: '1',
        clienteNome: 'Ana',
        vendedorUid: 'u',
        numeroNota: 1,
        data: _t,
        itens: const [],
        valorTotal: 100,
        tipo: TipoVenda.parcelado,
        updatedAt: _t,
      );
      final parcela = ParcelaModel(
        id: 'p',
        vendaId: 'v',
        numero: 1,
        valor: 100,
        vencimento: DateTime(2026, 11, 14),
        updatedAt: _t,
      );
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.value([_c('1', 'Ana')]),
        ),
        parcelas: AsyncValue.data([
          ItemPromissoria.de(venda, [parcela]),
        ]),
      );
      c.listen(agendaProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      final r = c.read(agendaProvider).requireValue.resumo;
      expect(r.vencendoNaData, 1);
      expect(r.aReceber, 100);
    });

    test('clientes com erro: AsyncError, sem loading', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.value([_rota('a', 'Centro')]),
          clientes: Stream.error(StateError('x')),
        ),
      );
      c.listen(agendaProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final e = c.read(agendaProvider);
      expect(e.hasError, isTrue);
      expect(e.isLoading, isFalse);
    });

    test('rotas com erro: AsyncError, sem loading', () async {
      final c = _container(
        _RepoFalso(
          rotas: Stream.error(StateError('x')),
          clientes: Stream.value([_c('1', 'Ana')]),
        ),
      );
      c.listen(agendaProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final e = c.read(agendaProvider);
      expect(e.hasError, isTrue);
      expect(e.isLoading, isFalse);
    });

    test('sem emissão: carrega, depois cai no cache', () {
      fakeAsync((async) {
        final c = _container(
          _RepoFalso(
            rotas: StreamController<List<RotaModel>>().stream,
            clientes: StreamController<List<ClienteModel>>().stream,
            rotasCache: [_rota('a', 'Centro')],
            clientesCache: [_c('1', 'Ana', rotaId: 'a')],
          ),
        );
        final sub = c.listen(agendaProvider, (_, _) {});

        async.elapse(const Duration(seconds: 1));
        expect(c.read(agendaProvider).isLoading, isTrue);

        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        final a = c.read(agendaProvider).requireValue;
        expect(a.itens.single.cliente.nome, 'Ana');
        sub.close();
      });
    });

    test('sem emissão e sem cache: vira erro, não spinner infinito', () {
      fakeAsync((async) {
        final c = _container(
          _RepoFalso(
            rotas: StreamController<List<RotaModel>>().stream,
            clientes: StreamController<List<ClienteModel>>().stream,
          ),
        );
        final sub = c.listen(agendaProvider, (_, _) {});
        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(agendaProvider).hasError, isTrue);
        sub.close();
      });
    });
  });
}
