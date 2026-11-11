import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/stream_com_cache.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/associar_clientes_sheet.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/detalhe_rota_sheet.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 13);

RotaModel _rota(String id, String nome, {bool deleted = false}) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
  deleted: deleted,
);

ClienteModel _c(
  String id,
  String nome, {
  String? rotaId,
  String cpf = '52998224725',
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: cpf,
  telefone: '',
  endereco: '',
  rotaId: rotaId,
  updatedAt: _t,
);

class _RepoQueFalha extends RotaRepository {
  _RepoQueFalha(super.db);

  @override
  Future<void> atribuirRotas(
    Map<String, String?> novasRotas, {
    DateTime? agora,
    int tamanhoLote = 450,
  }) => Future.error(Exception('falhou'));
}

Future<FakeFirebaseFirestore> _abrir(
  WidgetTester tester, {
  List<RotaModel>? rotas,
  List<ClienteModel>? clientes,
  RotaRepository Function(FakeFirebaseFirestore)? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = FakeFirebaseFirestore();
  for (final r in rotas ?? [_rota('a', 'Centro'), _rota('b', 'Norte')]) {
    await db.collection('rotas').doc(r.id).set(r.toMap());
  }
  for (final c in clientes ?? const <ClienteModel>[]) {
    await db.collection('clientes').doc(c.id).set(c.toMap());
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rotaRepositoryProvider.overrideWithValue(
          repo?.call(db) ?? RotaRepository(db),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => mostrarAssociarClientes(context, 'a'),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return db;
}

final _clientesPadrao = [
  _c('1', 'Ana (na rota)', rotaId: 'a'),
  _c('2', 'Beto (sem rota)'),
  _c('3', 'Caio (outra rota)', rotaId: 'b'),
  _c('4', 'Dora (rota excluída)', rotaId: 'velha'),
];

Finder _linha(String nome) => find.widgetWithText(CheckboxListTile, nome);

bool _marcado(WidgetTester tester, String nome) =>
    tester.widget<CheckboxListTile>(_linha(nome)).value!;

void main() {
  testWidgets('mostra selos e marca quem já está na rota', (tester) async {
    await _abrir(tester, clientes: _clientesPadrao);

    expect(_marcado(tester, 'Ana (na rota)'), isTrue);
    expect(_marcado(tester, 'Beto (sem rota)'), isFalse);
    expect(_marcado(tester, 'Caio (outra rota)'), isFalse);

    // Selo da OUTRA rota pelo nome; sem rota e rota excluída = "Sem rota".
    expect(find.text('NORTE'), findsOneWidget);
    expect(find.text('SEM ROTA'), findsNWidgets(2));
    // CPF só mascarado (LGPD).
    expect(find.text('529.***.***-25'), findsWidgets);
    expect(find.text('52998224725'), findsNothing);
    expect(find.text('Nenhuma alteração.'), findsOneWidget);
  });

  testWidgets('filtros rápidos', (tester) async {
    await _abrir(tester, clientes: _clientesPadrao);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sem rota'));
    await tester.pump();
    expect(find.text('Beto (sem rota)'), findsOneWidget);
    expect(find.text('Dora (rota excluída)'), findsOneWidget);
    expect(find.text('Ana (na rota)'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Desta rota'));
    await tester.pump();
    expect(find.text('Ana (na rota)'), findsOneWidget);
    expect(find.text('Beto (sem rota)'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'De outras rotas'));
    await tester.pump();
    expect(find.text('Caio (outra rota)'), findsOneWidget);
    expect(find.text('Ana (na rota)'), findsNothing);
  });

  testWidgets('busca por nome sem acento e por CPF parcial', (tester) async {
    await _abrir(
      tester,
      clientes: [
        _c('1', 'Ângela', cpf: '52998224725'),
        _c('2', 'Beto', cpf: '11144477735'),
      ],
    );

    await tester.enterText(find.byType(TextField), 'angela');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ângela'), findsOneWidget);
    expect(find.text('Beto'), findsNothing);

    await tester.enterText(find.byType(TextField), '111.444');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Ângela'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nenhum cliente encontrado'), findsOneWidget);
  });

  testWidgets('sem mudança, Salvar fica desabilitado e nada é gravado', (
    tester,
  ) async {
    final db = await _abrir(tester, clientes: _clientesPadrao);
    final botao = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Salvar'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(botao.onPressed, isNull);

    // Marcar e desmarcar de volta também zera a mudança.
    await tester.tap(_linha('Beto (sem rota)'));
    await tester.pump();
    expect(find.text('+1 associado'), findsOneWidget);
    await tester.tap(_linha('Beto (sem rota)'));
    await tester.pump();
    expect(find.text('Nenhuma alteração.'), findsOneWidget);

    expect(
      (await db.collection('clientes').doc('2').get()).data()!['rotaId'],
      isNull,
    );
  });

  testWidgets('associar, mover e remover: resumo, confirmação e gravação', (
    tester,
  ) async {
    final db = await _abrir(tester, clientes: _clientesPadrao);
    final antes1 = (await db.collection('clientes').doc('1').get()).data()!;

    await tester.tap(_linha('Beto (sem rota)')); // adiciona
    await tester.tap(_linha('Dora (rota excluída)')); // adiciona
    await tester.tap(_linha('Caio (outra rota)')); // move
    await tester.tap(_linha('Ana (na rota)')); // remove
    await tester.pump();

    expect(
      find.text('+3 associados, −1 removido, 1 movido de outra rota'),
      findsOneWidget,
    );

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Confirmação final avisa dos movidos.
    expect(find.text('Mover clientes'), findsOneWidget);
    expect(
      find.textContaining('1 cliente será movido de outra rota para esta.'),
      findsOneWidget,
    );

    // Cancelar mantém o sheet e não grava.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Associar clientes · Centro'), findsOneWidget);
    expect(
      (await db.collection('clientes').doc('2').get()).data()!['rotaId'],
      isNull,
    );

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    String? rota(String id, Map<String, dynamic> d) => d['rotaId'] as String?;
    Future<Map<String, dynamic>> doc(String id) async =>
        (await db.collection('clientes').doc(id).get()).data()!;
    expect(rota('2', await doc('2')), 'a');
    expect(rota('3', await doc('3')), 'a');
    expect(rota('4', await doc('4')), 'a');
    expect(rota('1', await doc('1')), isNull);
    expect(
      find.text('3 clientes associados e 1 cliente removido na rota Centro.'),
      findsOneWidget,
    );
    expect(find.text('Associar clientes · Centro'), findsNothing); // fechou
    // Só rotaId e updatedAt do cliente removido mudaram.
    final depois1 = await doc('1');
    expect(
      {...depois1}
        ..remove('rotaId')
        ..remove('updatedAt'),
      {...antes1}
        ..remove('rotaId')
        ..remove('updatedAt'),
    );
  });

  testWidgets('só adicionar não pede confirmação de movidos', (tester) async {
    final db = await _abrir(tester, clientes: _clientesPadrao);
    await tester.tap(_linha('Beto (sem rota)'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Mover clientes'), findsNothing);
    expect(find.text('1 cliente associado à rota Centro.'), findsOneWidget);
    expect(
      (await db.collection('clientes').doc('2').get()).data()!['rotaId'],
      'a',
    );
  });

  testWidgets('erro ao gravar mostra mensagem e mantém o sheet com a seleção', (
    tester,
  ) async {
    await _abrir(tester, clientes: _clientesPadrao, repo: _RepoQueFalha.new);
    await tester.tap(_linha('Beto (sem rota)'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar a associação. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Associar clientes · Centro'), findsOneWidget);
    expect(_marcado(tester, 'Beto (sem rota)'), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cliente bloqueado e inadimplente aparecem; excluído não', (
    tester,
  ) async {
    await _abrir(
      tester,
      clientes: [
        ClienteModel(
          id: '1',
          codigo: 'C-1',
          nome: 'Bloqueado',
          cpf: '52998224725',
          telefone: '',
          endereco: '',
          bloqueado: true,
          updatedAt: _t,
        ),
        ClienteModel(
          id: '2',
          codigo: 'C-2',
          nome: 'Apagado',
          cpf: '52998224725',
          telefone: '',
          endereco: '',
          updatedAt: _t,
          deleted: true,
        ),
      ],
    );
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Apagado'), findsNothing);
  });

  testWidgets('sem clientes cadastrados mostra o EmptyState', (tester) async {
    await _abrir(tester, clientes: const []);
    expect(find.text('Nenhum cliente cadastrado'), findsOneWidget);
  });

  testWidgets('rota excluída enquanto o sheet abre: "Rota não encontrada"', (
    tester,
  ) async {
    await _abrir(
      tester,
      rotas: [_rota('a', 'Centro', deleted: true)],
      clientes: _clientesPadrao,
    );
    expect(find.text('Rota não encontrada'), findsOneWidget);
  });

  group('estados de carregamento', () {
    Future<void> abrirComStreams(
      WidgetTester tester, {
      required Stream<List<ClienteModel>> clientes,
      List<ClienteModel> cache = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotaRepositoryProvider.overrideWithValue(
              _RepoFalso(clientes: clientes, clientesCache: cache),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => mostrarAssociarClientes(context, 'a'),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('clientes com erro: mensagem, sem spinner', (tester) async {
      await abrirComStreams(tester, clientes: Stream.error(StateError('x')));
      expect(find.text('Erro ao carregar os clientes'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('clientes sem emissão: carrega, depois cai para erro (sem '
        'spinner infinito)', (tester) async {
      await abrirComStreams(
        tester,
        clientes: StreamController<List<ClienteModel>>().stream,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(esperaPadraoAntesDoCache);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Erro ao carregar os clientes'), findsOneWidget);
    });

    testWidgets('clientes sem emissão mas com cache: usa o cache', (
      tester,
    ) async {
      await abrirComStreams(
        tester,
        clientes: StreamController<List<ClienteModel>>().stream,
        cache: [_c('1', 'Do cache')],
      );
      await tester.pump(esperaPadraoAntesDoCache);
      await tester.pump();
      expect(find.text('Do cache'), findsOneWidget);
    });
  });

  testWidgets('o botão do detalhe da rota fica desabilitado sem callback', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('rotas').doc('a').set(_rota('a', 'Centro').toMap());
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DetalheRotaSheet(rotaId: 'a')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final botao = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Associar clientes'),
    );
    expect(botao.onPressed, isNull);
  });
}

class _RepoFalso implements RotaRepository {
  _RepoFalso({required this.clientes, this.clientesCache = const []});

  final Stream<List<ClienteModel>> clientes;
  final List<ClienteModel> clientesCache;

  @override
  Stream<List<RotaModel>> observarAtivas() =>
      Stream.value([_rota('a', 'Centro')]);

  @override
  Future<List<RotaModel>> ativasEmCache() async => [_rota('a', 'Centro')];

  @override
  Stream<List<ClienteModel>> observarClientesAtivos() => clientes;

  @override
  Future<List<ClienteModel>> clientesAtivosEmCache() async => clientesCache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
