import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/navigation/app_routes.dart';
import 'package:cesta_basica_lopez_mobile/core/providers/regra_recomendacao_provider.dart';
import 'package:cesta_basica_lopez_mobile/core/services/discador.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/regra_recomendacao.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/agenda_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/agenda_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/recomendacao_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/recomendados_para_visitar.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/promissorias_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);
// Sábado, 14/11/2026.
final _agora = DateTime(2026, 11, 14, 9, 30);
final _data = DateTime(2026, 11, 14);

RotaModel _rota(String id, String nome) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
);

ClienteModel _c(
  String id,
  String nome, {
  String? rotaId,
  DateTime? ultima,
  double aberto = 0,
  DateTime? proximo,
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '52998224725',
  telefone: '(45) 99999-0000',
  endereco: 'Rua $id',
  rotaId: rotaId,
  ultimaCompra: ultima,
  valorEmAberto: aberto,
  proximoVencimento: proximo,
  updatedAt: _t,
);

final _recente = DateTime(2026, 11, 10);

class _Semente {
  _Semente({
    this.rotas = const [],
    this.clientes = const [],
    this.parcelas = const {},
  });
  final List<RotaModel> rotas;
  final List<ClienteModel> clientes;
  final Map<String, List<DateTime>> parcelas;
}

Future<FakeFirebaseFirestore> _banco(_Semente s) async {
  final db = FakeFirebaseFirestore();
  for (final r in s.rotas) {
    await db.collection('rotas').doc(r.id).set(r.toMap());
  }
  for (final c in s.clientes) {
    await db.collection('clientes').doc(c.id).set(c.toMap());
  }
  var n = 0;
  for (final e in s.parcelas.entries) {
    final vendaId = 'v-${e.key}';
    await db
        .collection('vendas')
        .doc(vendaId)
        .set(
          VendaModel(
            id: vendaId,
            clienteId: e.key,
            clienteNome: e.key,
            vendedorUid: 'u',
            numeroNota: ++n,
            data: _t,
            itens: const [],
            valorTotal: 100.0 * e.value.length,
            tipo: TipoVenda.parcelado,
            updatedAt: _t,
          ).toMap(),
        );
    for (final (i, venc) in e.value.indexed) {
      final p = ParcelaModel(
        id: '$vendaId-$i',
        vendaId: vendaId,
        numero: i + 1,
        valor: 100,
        vencimento: venc,
        updatedAt: _t,
      );
      await db
          .collection('vendas')
          .doc(vendaId)
          .collection('parcelas')
          .doc(p.id)
          .set(p.toMap());
    }
  }
  return db;
}

class _DiscadorFalso implements Discador {
  @override
  Future<bool> ligar(Uri uri) async => true;
}

Future<List<(String, Object?)>> _abrirAgenda(
  WidgetTester tester,
  _Semente semente, {
  List<Override> extras = const [],
}) async {
  tester.view.physicalSize = const Size(2400, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = await _banco(semente);
  final abertas = <(String, Object?)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
        vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
        agendaRelogioProvider.overrideWithValue(() => _agora),
        discadorProvider.overrideWithValue(_DiscadorFalso()),
        ...extras,
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          abertas.add((settings.name ?? '', settings.arguments));
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('rota ${settings.name}')),
          );
        },
        home: const AgendaScreen(recomendados: RecomendadosParaVisitar()),
      ),
    ),
  );
  await _bombear(tester);
  return abertas;
}

Future<void> _bombear(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

final _semente = _Semente(
  rotas: [_rota('a', 'Centro'), _rota('b', 'Norte')],
  clientes: [
    // Vencida há 4 dias.
    _c(
      '1',
      'Ana',
      rotaId: 'a',
      ultima: _recente,
      aberto: 100,
      proximo: DateTime(2026, 11, 10),
    ),
    // Vence hoje.
    _c('2', 'Beto', rotaId: 'a', ultima: _recente, aberto: 100, proximo: _data),
    // Inativo (reativação).
    _c('3', 'Caio', rotaId: 'b', ultima: DateTime(2026, 8, 1)),
    // Nunca comprou.
    _c('4', 'Dora'),
    // Quitado e recente: não aparece.
    _c('5', 'Eva', rotaId: 'a', ultima: _recente),
  ],
  parcelas: {
    '1': [DateTime(2026, 11, 10)],
    '2': [_data],
  },
);

void main() {
  group('bloco no slot da agenda', () {
    testWidgets('aparece com título, motivos e só quem tem o que visitar', (
      tester,
    ) async {
      await _abrirAgenda(tester, _semente);

      expect(find.text('Recomendados para visitar'), findsOneWidget);
      expect(find.text('Parcela vencida há 4 dias'), findsOneWidget);
      expect(find.text('Vence hoje'), findsOneWidget);
      expect(find.text('Sem comprar há 105 dias'), findsOneWidget);
      expect(find.text('Ainda não comprou'), findsOneWidget);
      // Selos do motivo.
      expect(find.text('EM ATRASO'), findsWidgets);
      expect(find.text('REATIVAR'), findsOneWidget);
      // Eva (quitada e recente) não é recomendada: só aparece na lista da
      // agenda, abaixo.
      expect(
        find.descendant(
          of: find.byType(RecomendadosParaVisitar),
          matching: find.text('Eva'),
        ),
        findsNothing,
      );
    });

    testWidgets('ordem: cobrança, vence, reativação, cliente novo', (
      tester,
    ) async {
      await _abrirAgenda(tester, _semente);
      double x(String texto) => tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byType(RecomendadosParaVisitar),
                  matching: find.text(texto),
                )
                .first,
          )
          .dx;
      expect(x('Ana'), lessThan(x('Beto')));
      expect(x('Beto'), lessThan(x('Caio')));
      expect(x('Caio'), lessThan(x('Dora')));
    });

    testWidgets('mostra no máximo N (5) no bloco; "Ver todos" mostra os '
        'demais', (tester) async {
      await _abrirAgenda(
        tester,
        _Semente(
          rotas: [_rota('a', 'Centro')],
          clientes: [
            for (var i = 1; i <= 7; i++)
              _c(
                '$i',
                'Cliente $i',
                rotaId: 'a',
                ultima: _recente,
                aberto: 100,
                proximo: _data.subtract(Duration(days: i)),
              ),
          ],
          parcelas: {
            for (var i = 1; i <= 7; i++)
              '$i': [_data.subtract(Duration(days: i))],
          },
        ),
      );
      Finder noBloco(String t) => find.descendant(
        of: find.byType(RecomendadosParaVisitar),
        matching: find.text(t),
      );
      expect(noBloco('Cliente 7'), findsOneWidget);
      expect(noBloco('Cliente 3'), findsOneWidget);
      expect(noBloco('Cliente 2'), findsNothing);
      expect(noBloco('Cliente 1'), findsNothing);

      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.text('Recomendados para visitar · 7'), findsOneWidget);
    });

    testWidgets('respeita a rota escolhida na agenda', (tester) async {
      await _abrirAgenda(tester, _semente);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
      await _bombear(tester);

      Finder noBloco(String t) => find.descendant(
        of: find.byType(RecomendadosParaVisitar),
        matching: find.text(t),
      );
      expect(noBloco('Caio'), findsOneWidget);
      expect(noBloco('Ana'), findsNothing);
      expect(noBloco('Dora'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas as rotas'));
      await _bombear(tester);
      expect(noBloco('Ana'), findsOneWidget);
    });

    testWidgets('toque abre o detalhe; o carrinho abre a nova venda', (
      tester,
    ) async {
      final abertas = await _abrirAgenda(tester, _semente);

      await tester.tap(
        find.descendant(
          of: find.byType(RecomendadosParaVisitar),
          matching: find.text('Ana'),
        ),
      );
      await tester.pumpAndSettle();
      expect(abertas.last, (AppRoutes.detalheCliente, '1'));
    });

    testWidgets('nova venda a partir do bloco pré-seleciona o cliente', (
      tester,
    ) async {
      final abertas = await _abrirAgenda(
        tester,
        _Semente(
          rotas: [_rota('a', 'Centro')],
          clientes: [_c('1', 'Ana', rotaId: 'a')],
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(RecomendadosParaVisitar),
          matching: find.byTooltip('Nova venda'),
        ),
      );
      await tester.pumpAndSettle();
      expect(abertas.last, (AppRoutes.novaVenda, '1'));
    });
  });

  group('Dispensar hoje', () {
    testWidgets('remove da recomendação; "Desfazer" devolve', (tester) async {
      await _abrirAgenda(tester, _semente);
      Finder noBloco(String t) => find.descendant(
        of: find.byType(RecomendadosParaVisitar),
        matching: find.text(t),
      );
      expect(noBloco('Ana'), findsOneWidget);

      await tester.tap(find.text('Dispensar hoje').first);
      await _bombear(tester);
      expect(noBloco('Ana'), findsNothing);
      expect(find.text('1 cliente dispensado hoje'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await _bombear(tester);
      expect(noBloco('Ana'), findsOneWidget);
      expect(find.textContaining('dispensado'), findsNothing);
    });

    testWidgets('vale para a data: trocar a data devolve o cliente', (
      tester,
    ) async {
      await _abrirAgenda(tester, _semente);
      Finder noBloco(String t) => find.descendant(
        of: find.byType(RecomendadosParaVisitar),
        matching: find.text(t),
      );

      await tester.tap(find.text('Dispensar hoje').first); // Ana, em 14/11
      await _bombear(tester);
      expect(noBloco('Ana'), findsNothing);

      await tester.tap(find.byTooltip('Próximo dia'));
      await _bombear(tester);
      expect(find.text('Domingo, 15/11/2026'), findsOneWidget);
      expect(noBloco('Ana'), findsOneWidget); // voltou

      await tester.tap(find.byTooltip('Dia anterior'));
      await _bombear(tester);
      expect(noBloco('Ana'), findsNothing); // 14/11 continua dispensado
    });
  });

  group('lista completa (Ver todos)', () {
    Future<void> abrirLista(WidgetTester tester) async {
      await _abrirAgenda(tester, _semente);
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra todos por prioridade, com ClientCard e ações', (
      tester,
    ) async {
      await abrirLista(tester);
      expect(find.text('Recomendados para visitar · 4'), findsOneWidget);
      expect(find.text('Dispensar hoje'), findsWidgets);
      expect(find.text('Detalhes'), findsWidgets);
      expect(find.text('Ligar'), findsWidgets);
    });

    testWidgets('filtra por motivo', (tester) async {
      await abrirLista(tester);
      final sheet = find.byType(DraggableScrollableSheet);
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(ChoiceChip, 'Reativar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sheet, matching: find.text('Caio')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Ana')),
        findsNothing,
      );
    });

    testWidgets('busca por nome sem acento', (tester) async {
      await abrirLista(tester);
      final sheet = find.byType(DraggableScrollableSheet);
      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        'DORA',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sheet, matching: find.text('Dora')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Ana')),
        findsNothing,
      );

      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        'zzz',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum cliente encontrado'), findsOneWidget);
    });

    testWidgets('dispensar na lista tira o cliente da lista e do bloco', (
      tester,
    ) async {
      await abrirLista(tester);
      final sheet = find.byType(DraggableScrollableSheet);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Dispensar hoje')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recomendados para visitar · 3'), findsOneWidget);
      expect(find.text('1 cliente dispensado hoje'), findsWidgets);
    });
  });

  group('estados do bloco', () {
    Future<void> abrirBloco(
      WidgetTester tester, {
      List<Override> extras = const [],
      RotaRepository? repo,
    }) async {
      tester.view.physicalSize = const Size(2400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = await _banco(_semente);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotaRepositoryProvider.overrideWithValue(
              repo ?? RotaRepository(db),
            ),
            vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
            agendaRelogioProvider.overrideWithValue(() => _agora),
            ...extras,
          ],
          child: const MaterialApp(
            home: Scaffold(body: RecomendadosParaVisitar()),
          ),
        ),
      );
      await _bombear(tester);
    }

    testWidgets('nada a visitar: EmptyState compacto no bloco', (tester) async {
      final db = await _banco(
        _Semente(
          rotas: [_rota('a', 'Centro')],
          clientes: [_c('1', 'Ana', rotaId: 'a', ultima: _recente)],
        ),
      );
      tester.view.physicalSize = const Size(2400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
            vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
            agendaRelogioProvider.overrideWithValue(() => _agora),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RecomendadosParaVisitar()),
          ),
        ),
      );
      await _bombear(tester);
      expect(find.text('Nenhum cliente para visitar agora'), findsOneWidget);
      expect(find.text('Ver todos'), findsNothing);
    });

    testWidgets('clientes com erro: mensagem, sem spinner', (tester) async {
      await abrirBloco(
        tester,
        extras: [
          clientesDasRotasProvider.overrideWith(
            (ref) => Stream.error(StateError('x')),
          ),
        ],
      );
      expect(find.text('Erro ao carregar as recomendações'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('sem emissão: carrega e depois cai para erro, sem spinner '
        'infinito', (tester) async {
      await abrirBloco(
        tester,
        extras: [
          clientesDasRotasProvider.overrideWith(
            (ref) => comFallbackDeCache<ClienteModel>(
              StreamController<List<ClienteModel>>().stream,
              () async => const [],
            ),
          ),
        ],
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(esperaPadraoAntesDoCache);
      await _bombear(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Erro ao carregar as recomendações'), findsOneWidget);
    });

    testWidgets('parcelas carregando: recomenda pelo resumo, com aviso '
        'discreto', (tester) async {
      await abrirBloco(
        tester,
        extras: [
          promissoriasProvider.overrideWith(
            (ref, id) => const AsyncValue.loading(),
          ),
        ],
      );
      expect(
        find.textContaining('as parcelas ainda estão carregando'),
        findsOneWidget,
      );
      // Estimado pelo proximoVencimento do cliente.
      expect(find.text('Parcela vencida há 4 dias'), findsOneWidget);
      expect(find.text('Vence hoje'), findsOneWidget);
    });
  });

  group('recomendacoesProvider', () {
    ProviderContainer container({
      required RotaRepository repo,
      List<Override> extras = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          rotaRepositoryProvider.overrideWithValue(repo),
          agendaRelogioProvider.overrideWithValue(() => _agora),
          // Sem as parcelas, a agenda estima pelo resumo do cliente
          // (proximoVencimento e valorEmAberto da semente).
          promissoriasProvider.overrideWith(
            (ref, id) => const AsyncValue.loading(),
          ),
          ...extras,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'regra substituível pelo provider muda a quantidade e a ordem',
      () async {
        final db = await _banco(_semente);
        final c = container(
          repo: RotaRepository(db),
          extras: [
            regraRecomendacaoProvider.overrideWithValue(
              const RegraRecomendacao(quantidade: 2),
            ),
          ],
        );
        c.listen(recomendacoesProvider, (_, _) {});
        await c.read(rotasAtivasProvider.future);
        await c.read(clientesDasRotasProvider.future);

        final r = c.read(recomendacoesProvider).requireValue;
        expect(r.melhores, hasLength(2));
        expect(r.todas.length, greaterThan(2));
      },
    );

    test('dispensados são por data', () async {
      final db = await _banco(_semente);
      final c = container(repo: RotaRepository(db));
      c.listen(recomendacoesProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);

      final antes = c.read(recomendacoesProvider).requireValue.todas.length;
      c.read(dispensadosHojeProvider.notifier).dispensar('1', _data);
      var r = c.read(recomendacoesProvider).requireValue;
      expect(r.todas.length, antes - 1);
      expect(r.dispensados, 1);

      c.read(selecaoAgendaProvider.notifier).proximoDia();
      r = c.read(recomendacoesProvider).requireValue;
      expect(r.dispensados, 0);

      c.read(selecaoAgendaProvider.notifier).diaAnterior();
      expect(c.read(recomendacoesProvider).requireValue.dispensados, 1);

      c.read(dispensadosHojeProvider.notifier).restaurar(_data);
      expect(c.read(recomendacoesProvider).requireValue.dispensados, 0);
    });

    test('dispensar o mesmo cliente duas vezes conta uma', () async {
      final db = await _banco(_semente);
      final c = container(repo: RotaRepository(db));
      c.listen(recomendacoesProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);
      final n = c.read(dispensadosHojeProvider.notifier);
      n.dispensar('1', _data);
      n.dispensar('1', DateTime(2026, 11, 14, 18));
      expect(c.read(recomendacoesProvider).requireValue.dispensados, 1);
    });

    test('erro dos clientes: AsyncError, sem loading', () async {
      final db = await _banco(_semente);
      final c = container(
        repo: RotaRepository(db),
        extras: [
          clientesDasRotasProvider.overrideWith(
            (ref) => Stream.error(StateError('x')),
          ),
        ],
      );
      c.listen(recomendacoesProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final e = c.read(recomendacoesProvider);
      expect(e.hasError, isTrue);
      expect(e.isLoading, isFalse);
    });

    test('sem emissão e sem cache: vira erro, não spinner infinito', () {
      fakeAsync((async) {
        final c = container(
          repo: RotaRepository(FakeFirebaseFirestore()),
          extras: [
            rotasAtivasProvider.overrideWith(
              (ref) => comFallbackDeCache<RotaModel>(
                StreamController<List<RotaModel>>().stream,
                () async => const [],
              ),
            ),
            clientesDasRotasProvider.overrideWith(
              (ref) => comFallbackDeCache<ClienteModel>(
                StreamController<List<ClienteModel>>().stream,
                () async => const [],
              ),
            ),
          ],
        );
        final sub = c.listen(recomendacoesProvider, (_, _) {});
        async.elapse(const Duration(seconds: 1));
        expect(c.read(recomendacoesProvider).isLoading, isTrue);
        async.elapse(esperaPadraoAntesDoCache);
        async.flushMicrotasks();
        expect(c.read(recomendacoesProvider).hasError, isTrue);
        sub.close();
      });
    });

    test('parcelas indisponíveis: recomenda e marca como estimado', () async {
      final db = await _banco(_semente);
      // O container já usa "parcelas carregando" por padrão.
      final c = container(repo: RotaRepository(db));
      c.listen(recomendacoesProvider, (_, _) {});
      await c.read(rotasAtivasProvider.future);
      await c.read(clientesDasRotasProvider.future);
      final r = c.read(recomendacoesProvider).requireValue;
      expect(r.parcelasDisponiveis, isFalse);
      expect(r.todas, isNotEmpty);
    });
  });
}
