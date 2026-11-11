import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/dados_cadastrais_cliente.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/cliente_form.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/cliente_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/clientes_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/alterar_rota_cliente_sheet.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
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

ClienteModel _c(String id, String nome, {String? rotaId}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0000',
  endereco: 'Rua $id',
  rotaId: rotaId,
  updatedAt: _t,
);

DadosCadastraisCliente _dados(
  ClienteModel c, {
  String? rotaId,
  String? telefone,
}) => DadosCadastraisCliente(
  nome: c.nome,
  cpf: c.cpf,
  telefone: telefone ?? c.telefone,
  endereco: c.endereco,
  rotaId: rotaId,
);

Future<FakeFirebaseFirestore> _banco({
  List<RotaModel> rotas = const [],
  List<ClienteModel> clientes = const [],
}) async {
  final db = FakeFirebaseFirestore();
  for (final r in rotas) {
    await db.collection('rotas').doc(r.id).set(r.toMap());
  }
  for (final c in clientes) {
    await db.collection('clientes').doc(c.id).set(c.toMap());
  }
  return db;
}

void main() {
  group('SalvarClienteNotifier com rota', () {
    late FakeFirebaseFirestore db;
    late ProviderContainer container;

    Future<void> preparar({
      List<ClienteModel> clientes = const [],
      List<RotaModel>? rotas,
    }) async {
      db = await _banco(
        rotas:
            rotas ?? [_rota('a', 'Centro'), _rota('x', 'Velha', deleted: true)],
        clientes: clientes,
      );
      container = ProviderContainer(
        overrides: [
          clienteRepositoryProvider.overrideWithValue(ClienteRepository(db)),
          rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(rotasAtivasProvider, (_, _) {});
      await container.read(rotasAtivasProvider.future);
    }

    Future<Map<String, dynamic>> doc(String id) async =>
        (await db.collection('clientes').doc(id).get()).data()!;

    test('mudar a rota grava rotaId pela camada de rota', () async {
      final original = _c('1', 'Ana');
      await preparar(clientes: [original]);

      await container
          .read(salvarClienteProvider.notifier)
          .atualizar(original, _dados(original, rotaId: 'a'));

      expect((await doc('1'))['rotaId'], 'a');
    });

    test('tirar a rota (Sem rota) limpa o rotaId', () async {
      final original = _c('1', 'Ana', rotaId: 'a');
      await preparar(clientes: [original]);

      await container
          .read(salvarClienteProvider.notifier)
          .atualizar(original, _dados(original, rotaId: null));

      expect((await doc('1'))['rotaId'], isNull);
    });

    test('editar o telefone sem mexer na rota mantém a rota', () async {
      final original = _c('1', 'Ana', rotaId: 'a');
      await preparar(clientes: [original]);

      await container
          .read(salvarClienteProvider.notifier)
          .atualizar(
            original,
            _dados(original, rotaId: 'a', telefone: '(45) 98888-1111'),
          );

      final d = await doc('1');
      expect(d['rotaId'], 'a');
      expect(d['telefone'], '(45) 98888-1111');
    });

    test('texto livre antigo não é limpo ao editar outros campos', () async {
      final original = _c('1', 'Ana', rotaId: 'Zona Sul');
      await preparar(clientes: [original]);

      // O formulário mostra "Sem rota" (null) e o vendedor não toca nela.
      await container
          .read(salvarClienteProvider.notifier)
          .atualizar(
            original,
            _dados(original, rotaId: null, telefone: '(45) 98888-1111'),
          );

      final d = await doc('1');
      expect(d['rotaId'], 'Zona Sul');
      expect(d['telefone'], '(45) 98888-1111');
    });

    test('escolher uma rota excluída é recusado, sem gravar', () async {
      final original = _c('1', 'Ana');
      await preparar(clientes: [original]);

      await expectLater(
        container
            .read(salvarClienteProvider.notifier)
            .atualizar(original, _dados(original, rotaId: 'x')),
        throwsA(isA<StateError>()),
      );
      expect((await doc('1'))['rotaId'], isNull);
    });

    test(
      'cadastrar com rota ativa grava o id; com rota inexistente lança',
      () async {
        await preparar();
        final n = container.read(salvarClienteProvider.notifier);
        final novo = _c('n', 'Novo');

        await n.cadastrar(_dados(novo, rotaId: 'a'));
        final docs = (await db.collection('clientes').get()).docs;
        expect(docs.single.data()['rotaId'], 'a');

        await expectLater(
          n.cadastrar(_dados(novo, rotaId: 'fantasma')),
          throwsA(isA<StateError>()),
        );
        expect((await db.collection('clientes').get()).docs, hasLength(1));
      },
    );

    test('rotas ainda não carregadas: o valor original é mantido', () async {
      final original = _c('1', 'Ana', rotaId: 'a');
      db = await _banco(clientes: [original]);
      container = ProviderContainer(
        overrides: [
          clienteRepositoryProvider.overrideWithValue(ClienteRepository(db)),
          rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      // O formulário devolve o rotaId cru quando as rotas não carregaram.
      await container
          .read(salvarClienteProvider.notifier)
          .atualizar(original, _dados(original, rotaId: 'a'));
      expect((await doc('1'))['rotaId'], 'a');
    });
  });

  group('ClienteForm: seletor de rota', () {
    Future<DadosCadastraisCliente?> abrir(
      WidgetTester tester, {
      ClienteModel? inicial,
      List<RotaModel>? rotas,
      Object? erroRotas,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DadosCadastraisCliente? salvo;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotasAtivasProvider.overrideWith(
              (ref) => erroRotas != null
                  ? Stream.error(erroRotas)
                  : Stream.value(
                      rotas ??
                          [
                            _rota('a', 'Centro'),
                            _rota('b', 'Norte'),
                            _rota('x', 'Velha', deleted: true),
                          ],
                    ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ClienteForm(
                inicial: inicial,
                textoBotao: 'Salvar',
                salvando: false,
                onSalvar: (d) => salvo = d,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      // O formulário devolve o resultado por callback: expõe via closure.
      _ultimo = () => salvo;
      return null;
    }

    testWidgets('mostra as rotas reais e "Sem rota", sem a excluída', (
      tester,
    ) async {
      await abrir(tester, inicial: _c('1', 'Ana', rotaId: 'a'));

      expect(find.text('Rota (opcional)'), findsOneWidget);
      expect(find.text('Centro'), findsOneWidget); // selecionada

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Sem rota'), findsWidgets);
      expect(find.text('Norte'), findsWidgets);
      expect(find.text('Velha'), findsNothing);
      expect(find.textContaining('Texto livre'), findsNothing);
    });

    testWidgets('escolher outra rota devolve o id da rota', (tester) async {
      await abrir(tester, inicial: _c('1', 'Ana'));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Norte').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(_ultimo!()!.rotaId, 'b');
    });

    testWidgets('texto livre antigo aparece como "Sem rota" e devolve nulo', (
      tester,
    ) async {
      await abrir(tester, inicial: _c('1', 'Ana', rotaId: 'Zona Sul'));
      expect(find.text('Sem rota'), findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(_ultimo!()!.rotaId, isNull);
    });

    testWidgets('rota excluída aparece como "Sem rota"', (tester) async {
      await abrir(tester, inicial: _c('1', 'Ana', rotaId: 'x'));
      expect(find.text('Sem rota'), findsOneWidget);
      expect(find.text('Velha'), findsNothing);
    });

    testWidgets('rotas com erro: campo desabilitado e rota original mantida', (
      tester,
    ) async {
      await abrir(
        tester,
        inicial: _c('1', 'Ana', rotaId: 'a'),
        erroRotas: StateError('x'),
      );
      expect(
        find.textContaining('Não foi possível carregar as rotas'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(_ultimo!()!.rotaId, 'a');
    });
  });

  group('AlterarRotaClienteSheet', () {
    testWidgets('troca a rota e atualiza só rotaId/updatedAt', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cliente = _c('1', 'Ana');
      final db = await _banco(
        rotas: [_rota('a', 'Centro'), _rota('b', 'Norte')],
        clientes: [cliente],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clienteRepositoryProvider.overrideWithValue(ClienteRepository(db)),
            rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      mostrarAlterarRotaDoCliente(context, cliente),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Norte').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final d = (await db.collection('clientes').doc('1').get()).data()!;
      expect(d['rotaId'], 'b');
      expect(d['nome'], 'Ana');
      expect(find.text('Rota atualizada.'), findsOneWidget);
    });

    testWidgets('sem mudança fecha sem gravar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cliente = _c('1', 'Ana', rotaId: 'a');
      final db = await _banco(
        rotas: [_rota('a', 'Centro')],
        clientes: [cliente],
      );
      final antes = (await db.collection('clientes').doc('1').get()).data();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clienteRepositoryProvider.overrideWithValue(ClienteRepository(db)),
            rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      mostrarAlterarRotaDoCliente(context, cliente),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect((await db.collection('clientes').doc('1').get()).data(), antes);
      expect(find.text('Salvar'), findsNothing);
    });
  });

  group('listagem de clientes: filtro e nome da rota', () {
    Future<void> abrir(
      WidgetTester tester, {
      required List<ClienteModel> clientes,
      List<RotaModel>? rotas,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = await _banco(
        rotas: rotas ?? [_rota('a', 'Centro'), _rota('b', 'Norte')],
        clientes: clientes,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clienteRepositoryProvider.overrideWithValue(ClienteRepository(db)),
            rotaRepositoryProvider.overrideWithValue(RotaRepository(db)),
          ],
          child: const MaterialApp(home: ClientesScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    final clientes = [
      _c('1', 'Ana', rotaId: 'a'),
      _c('2', 'Beto', rotaId: 'b'),
      _c('3', 'Caio'),
      _c('4', 'Dora', rotaId: 'velha'),
    ];

    testWidgets('o card mostra o nome da rota, só de rota ativa', (
      tester,
    ) async {
      await abrir(tester, clientes: clientes);
      expect(find.text('Rota: Centro'), findsOneWidget);
      expect(find.text('Rota: Norte'), findsOneWidget);
      expect(find.textContaining('velha'), findsNothing);
      expect(find.text('Dora'), findsOneWidget); // não quebra
    });

    testWidgets('filtra por rota, por "Sem rota" e volta a todas', (
      tester,
    ) async {
      await abrir(tester, clientes: clientes);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Centro'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Sem rota'));
      await tester.pump();
      await tester.pump();
      // Sem rota + rota inexistente (Dora).
      expect(find.text('Caio'), findsOneWidget);
      expect(find.text('Dora'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas as rotas'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
    });

    testWidgets('combina com o filtro de status de pagamento', (tester) async {
      await abrir(
        tester,
        clientes: [
          _c('1', 'Ana', rotaId: 'a'),
          ClienteModel(
            id: '2',
            codigo: 'C-2',
            nome: 'Beto',
            cpf: '529.982.247-25',
            telefone: '',
            endereco: 'Rua 2',
            rotaId: 'a',
            bloqueado: true,
            updatedAt: _t,
          ),
        ],
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Centro'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Bloqueado'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
    });

    testWidgets('rota sem clientes: mensagem de vazio', (tester) async {
      await abrir(tester, clientes: [_c('1', 'Ana', rotaId: 'a')]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Nenhum cliente encontrado'), findsOneWidget);
      expect(find.text('Nenhum cliente nesta rota.'), findsOneWidget);
    });

    testWidgets('sem rotas cadastradas, a linha de filtro de rota some', (
      tester,
    ) async {
      await abrir(tester, rotas: const [], clientes: [_c('1', 'Ana')]);
      expect(find.widgetWithText(ChoiceChip, 'Sem rota'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
    });
  });
}

/// Último valor devolvido pelo `ClienteForm` do teste.
DadosCadastraisCliente? Function()? _ultimo;
