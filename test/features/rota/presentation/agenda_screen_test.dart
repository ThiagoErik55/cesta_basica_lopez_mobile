import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/navigation/app_routes.dart';
import 'package:cesta_basica_lopez_mobile/core/services/discador.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/formatadores.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/agenda_vendedor.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/agenda_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/agenda_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/promissorias_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);
// Sábado, 14/11/2026.
final _agora = DateTime(2026, 11, 14, 9, 30);

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
  String telefone = '(45) 99999-0000',
  double aberto = 0,
  DateTime? proximo,
  bool bloqueado = false,
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '52998224725',
  telefone: telefone,
  endereco: 'Rua $id',
  rotaId: rotaId,
  valorEmAberto: aberto,
  proximoVencimento: proximo,
  bloqueado: bloqueado,
  updatedAt: _t,
);

class _DiscadorFalso implements Discador {
  final chamadas = <Uri>[];
  bool resultado = true;

  @override
  Future<bool> ligar(Uri uri) async {
    chamadas.add(uri);
    return resultado;
  }
}

class _Semente {
  _Semente({
    this.rotas = const [],
    this.clientes = const [],
    this.parcelas = const {},
  });
  final List<RotaModel> rotas;
  final List<ClienteModel> clientes;

  /// clienteId → vencimentos (uma parcela de R$ 100 por data).
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

class _Hospedeiro {
  _Hospedeiro(this.discador);
  final _DiscadorFalso discador;
  final rotasAbertas = <(String, Object?)>[];
}

Future<_Hospedeiro> _abrir(
  WidgetTester tester,
  _Semente semente, {
  List<Override> extras = const [],
  Widget? recomendados,
  ValueChanged<ItemAgenda>? aoMarcar,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = await _banco(semente);
  final host = _Hospedeiro(_DiscadorFalso());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
        vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
        agendaRelogioProvider.overrideWithValue(() => _agora),
        discadorProvider.overrideWithValue(host.discador),
        ...extras,
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          host.rotasAbertas.add((settings.name ?? '', settings.arguments));
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('rota ${settings.name}')),
          );
        },
        home: AgendaScreen(
          recomendados: recomendados,
          aoMarcarVisitaRealizada: aoMarcar,
        ),
      ),
    ),
  );
  // Streams do Firestore falso + providers encadeados.
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  return host;
}

Future<void> _bombear(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

double _y(WidgetTester tester, String texto) =>
    tester.getTopLeft(find.text(texto).first).dy;

final _semente = _Semente(
  rotas: [_rota('a', 'Centro'), _rota('b', 'Norte')],
  clientes: [
    _c(
      '1',
      'Ana Centro',
      rotaId: 'a',
      aberto: 100,
      proximo: DateTime(2026, 11, 14),
    ),
    _c(
      '2',
      'Beto Centro',
      rotaId: 'a',
      aberto: 100,
      proximo: DateTime(2026, 11, 10),
    ),
    _c('3', 'Caio Norte', rotaId: 'b'),
    _c('4', 'Dora Sem Rota'),
    _c('5', 'Eva Sem Fone', rotaId: 'a', telefone: '123'),
  ],
  parcelas: {
    '1': [DateTime(2026, 11, 14)], // vence hoje
    '2': [DateTime(2026, 11, 10)], // vencida há 4 dias
  },
);

void main() {
  testWidgets('abre em hoje, com todas as rotas, resumo e grupos', (
    tester,
  ) async {
    await _abrir(tester, _semente);

    expect(find.text('Sábado, 14/11/2026'), findsOneWidget);
    expect(find.text('Hoje · toque para escolher'), findsOneWidget);
    expect(find.text('Todas as rotas'), findsOneWidget);

    // Resumo: 5 clientes, 1 vence na data, 1 em atraso, R$ 200 a receber.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Vencem na data'), findsOneWidget);
    expect(find.text(formatarMoeda(200)), findsOneWidget);

    // Grupos por rota, com "Sem rota" por último.
    expect(find.text('Centro · 3'), findsOneWidget);
    expect(find.text('Norte · 1'), findsOneWidget);
    expect(find.text('Sem rota · 1'), findsOneWidget);
    expect(_y(tester, 'Centro · 3'), lessThan(_y(tester, 'Norte · 1')));
    expect(_y(tester, 'Norte · 1'), lessThan(_y(tester, 'Sem rota · 1')));
  });

  testWidgets('destaques e ordem: vencida primeiro, depois vencendo', (
    tester,
  ) async {
    await _abrir(tester, _semente);

    expect(find.text('Vencida há 4 dias'), findsOneWidget);
    expect(find.text('Vence nesta data'), findsOneWidget);
    // No grupo Centro: Beto (vencida) → Ana (vence hoje) → Eva (nada).
    expect(_y(tester, 'Beto Centro'), lessThan(_y(tester, 'Ana Centro')));
    expect(_y(tester, 'Ana Centro'), lessThan(_y(tester, 'Eva Sem Fone')));
    // Dados do cartão.
    expect(
      find.textContaining('Em aberto ${formatarMoeda(100)}'),
      findsWidgets,
    );
    expect(find.textContaining('Última compra nenhuma'), findsWidgets);
  });

  testWidgets('trocar a rota mostra só os clientes dela, sem grupos', (
    tester,
  ) async {
    await _abrir(tester, _semente);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
    await _bombear(tester);

    expect(find.text('Caio Norte'), findsOneWidget);
    expect(find.text('Ana Centro'), findsNothing);
    expect(find.text('Dora Sem Rota'), findsNothing); // sem rota não entra
    expect(find.textContaining(' · 1'), findsNothing); // sem cabeçalho de grupo

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas as rotas'));
    await _bombear(tester);
    expect(find.text('Dora Sem Rota'), findsOneWidget);
  });

  testWidgets('trocar a data atualiza destaques e resumo', (tester) async {
    await _abrir(tester, _semente);
    expect(find.text('Vence nesta data'), findsOneWidget);

    // Dia seguinte: a parcela de hoje passa a vencida há 1 dia.
    await tester.tap(find.byTooltip('Próximo dia'));
    await _bombear(tester);
    expect(find.text('Domingo, 15/11/2026'), findsOneWidget);
    expect(find.text('Vencida há 1 dia'), findsOneWidget);
    expect(find.text('Vencida há 5 dias'), findsOneWidget);
    expect(find.text('Vence nesta data'), findsNothing);

    // Dia anterior ao de hoje: a parcela de 10/11 ainda não venceu.
    await tester.tap(find.text('Hoje'));
    await _bombear(tester);
    await tester.tap(find.byTooltip('Dia anterior'));
    await _bombear(tester);
    expect(find.text('Sexta, 13/11/2026'), findsOneWidget);
    expect(find.text('Vencida há 3 dias'), findsOneWidget);
    expect(find.text('Vence nesta data'), findsNothing);
  });

  testWidgets('"Hoje" só aparece fora de hoje e volta para hoje', (
    tester,
  ) async {
    await _abrir(tester, _semente);
    expect(find.widgetWithText(TextButton, 'Hoje'), findsNothing);

    await tester.tap(find.byTooltip('Próximo dia'));
    await _bombear(tester);
    expect(find.widgetWithText(TextButton, 'Hoje'), findsOneWidget);
    expect(find.text('Toque para escolher'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Hoje'));
    await _bombear(tester);
    expect(find.text('Sábado, 14/11/2026'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hoje'), findsNothing);
  });

  testWidgets('o calendário escolhe qualquer data', (tester) async {
    await _abrir(tester, _semente);
    await tester.tap(find.text('Hoje · toque para escolher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _bombear(tester);
    expect(find.text('Sexta, 20/11/2026'), findsOneWidget);
  });

  testWidgets('filtros rápidos e busca sem acento', (tester) async {
    await _abrir(
      tester,
      _Semente(
        rotas: [_rota('a', 'Centro')],
        clientes: [
          ..._semente.clientes.where((c) => c.rotaId == 'a'),
          _c('9', 'Ângela', rotaId: 'a', bloqueado: true),
        ],
        parcelas: _semente.parcelas,
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'A cobrar'));
    await _bombear(tester);
    expect(find.text('Ana Centro'), findsOneWidget);
    expect(find.text('Beto Centro'), findsOneWidget);
    expect(find.text('Eva Sem Fone'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Em atraso'));
    await _bombear(tester);
    expect(find.text('Beto Centro'), findsOneWidget);
    expect(find.text('Ana Centro'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bloqueados'));
    await _bombear(tester);
    expect(find.text('Ângela'), findsOneWidget);
    expect(find.text('Beto Centro'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await _bombear(tester);
    await tester.enterText(find.byType(TextField), 'angela');
    await tester.pump(const Duration(milliseconds: 400));
    await _bombear(tester);
    expect(find.text('Ângela'), findsOneWidget);
    expect(find.text('Ana Centro'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await _bombear(tester);
    expect(find.text('Nenhum cliente encontrado'), findsOneWidget);
  });

  group('ações rápidas', () {
    testWidgets('Ligar usa tel: normalizado; sem telefone válido não há '
        'botão', (tester) async {
      final host = await _abrir(tester, _semente);

      // 5 clientes, 4 com telefone válido.
      expect(find.text('Ligar'), findsNWidgets(4));

      await tester.tap(find.text('Ligar').first);
      await tester.pump();
      expect(host.discador.chamadas.single.toString(), 'tel:+5545999990000');
    });

    testWidgets('falha ao abrir o discador avisa', (tester) async {
      final host = await _abrir(tester, _semente);
      host.discador.resultado = false;
      await tester.tap(find.text('Ligar').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Não foi possível abrir o discador.'), findsOneWidget);
    });

    testWidgets('Nova venda abre a venda com o cliente pré-selecionado', (
      tester,
    ) async {
      final host = await _abrir(
        tester,
        _Semente(
          rotas: [_rota('a', 'Centro')],
          clientes: [_c('1', 'Ana', rotaId: 'a')],
        ),
      );
      await tester.tap(find.text('Nova venda'));
      await tester.pumpAndSettle();
      expect(host.rotasAbertas.last, (AppRoutes.novaVenda, '1'));
    });

    testWidgets('Detalhes e toque no cartão abrem o detalhe do cliente', (
      tester,
    ) async {
      final host = await _abrir(
        tester,
        _Semente(
          rotas: [_rota('a', 'Centro')],
          clientes: [_c('1', 'Ana', rotaId: 'a')],
        ),
      );
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(host.rotasAbertas.last, (AppRoutes.detalheCliente, '1'));
    });

    testWidgets('visita realizada só aparece com o callback ligado', (
      tester,
    ) async {
      await _abrir(tester, _Semente(clientes: [_c('1', 'Ana')]));
      expect(find.text('Visita realizada'), findsNothing);
    });

    testWidgets('com o callback, o botão chama com o cliente', (tester) async {
      ItemAgenda? marcado;
      await _abrir(
        tester,
        _Semente(clientes: [_c('1', 'Ana')]),
        aoMarcar: (i) => marcado = i,
      );
      await tester.tap(find.text('Visita realizada'));
      expect(marcado?.cliente.id, '1');
    });
  });

  testWidgets('o espaço dos recomendados (KAN-48) aparece quando informado', (
    tester,
  ) async {
    await _abrir(
      tester,
      _Semente(clientes: [_c('1', 'Ana')]),
      recomendados: const Text('Recomendados para visitar'),
    );
    expect(find.text('Recomendados para visitar'), findsOneWidget);
  });

  group('estados', () {
    testWidgets('sem clientes mostra o EmptyState', (tester) async {
      await _abrir(tester, _Semente(rotas: [_rota('a', 'Centro')]));
      expect(find.text('Nenhum cliente na agenda'), findsOneWidget);
    });

    testWidgets('rota sem clientes mostra o EmptyState da rota', (
      tester,
    ) async {
      await _abrir(
        tester,
        _Semente(
          rotas: [_rota('a', 'Centro'), _rota('b', 'Norte')],
          clientes: [_c('1', 'Ana', rotaId: 'a')],
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
      await _bombear(tester);
      expect(find.text('Nenhum cliente nesta rota'), findsOneWidget);
    });

    testWidgets('parcelas ainda carregando: agenda aparece e o a receber '
        'mostra "—"', (tester) async {
      await _abrir(
        tester,
        _semente,
        extras: [
          promissoriasProvider.overrideWith(
            (ref, clienteId) => const AsyncValue.loading(),
          ),
        ],
      );
      expect(find.text('Ana Centro'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('Carregando as parcelas'), findsOneWidget);
      // Estimado pelo resumo do cliente.
      expect(find.text('Vence nesta data'), findsOneWidget);
      expect(find.text('Vencida há 4 dias'), findsOneWidget);
    });

    testWidgets('clientes com erro: mensagem, sem spinner', (tester) async {
      await _abrir(
        tester,
        _semente,
        extras: [
          clientesDasRotasProviderOverride(
            (ref) => Stream.error(StateError('x')),
          ),
        ],
      );
      expect(find.text('Erro ao carregar a agenda'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('clientes sem emissão: carrega e depois cai para erro, sem '
        'spinner infinito', (tester) async {
      await _abrir(
        tester,
        _semente,
        extras: [
          clientesDasRotasProviderOverride(
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
      expect(find.text('Erro ao carregar a agenda'), findsOneWidget);
    });

    testWidgets('rotas com erro: mensagem, sem spinner', (tester) async {
      await _abrir(
        tester,
        _semente,
        extras: [
          rotasAtivasProviderOverride((ref) => Stream.error(StateError('x'))),
        ],
      );
      expect(find.text('Erro ao carregar a agenda'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('tempo real: cliente associado à rota aparece sem recarregar', (
    tester,
  ) async {
    final db = await _banco(_semente);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
          vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
          agendaRelogioProvider.overrideWithValue(() => _agora),
        ],
        child: const MaterialApp(home: AgendaScreen()),
      ),
    );
    await _bombear(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
    await _bombear(tester);
    expect(find.text('Dora Sem Rota'), findsNothing);

    await db.collection('clientes').doc('4').update({'rotaId': 'b'});
    await _bombear(tester);
    expect(find.text('Dora Sem Rota'), findsOneWidget);
  });
}

Override clientesDasRotasProviderOverride(
  Stream<List<ClienteModel>> Function(Ref ref) criar,
) => clientesDasRotasProvider.overrideWith(criar);

Override rotasAtivasProviderOverride(
  Stream<List<RotaModel>> Function(Ref ref) criar,
) => rotasAtivasProvider.overrideWith(criar);
