import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_form_sheet.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rotas_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 12);

RotaModel _rota(
  String id,
  String nome, {
  LinhaAtendimento linha = LinhaAtendimento.toledo,
}) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: linha,
  updatedAt: _t,
);

ClienteModel _cliente(String id, String nome, String rotaId) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '00000000000',
  telefone: '',
  endereco: '',
  rotaId: rotaId,
  updatedAt: _t,
);

class _Semente {
  const _Semente({this.rotas = const [], this.clientes = const []});
  final List<RotaModel> rotas;
  final List<ClienteModel> clientes;
}

Future<FakeFirebaseFirestore> _abrir(
  WidgetTester tester, {
  _Semente semente = const _Semente(),
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = FakeFirebaseFirestore();
  for (final r in semente.rotas) {
    await db.collection('rotas').doc(r.id).set(r.toMap());
  }
  for (final c in semente.clientes) {
    await db.collection('clientes').doc(c.id).set(c.toMap());
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [rotaRepositoryProvider.overrideWithValue(RotaRepository(db))],
      child: const MaterialApp(home: RotasScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return db;
}

Finder _campoNome() => find.widgetWithText(TextFormField, 'Nome da rota');

void main() {
  group('lista', () {
    testWidgets('mostra nome, linha, código e quantidade de clientes', (
      tester,
    ) async {
      await _abrir(
        tester,
        semente: _Semente(
          rotas: [
            _rota('1', 'Centro'),
            _rota('2', 'Zona Sul', linha: LinhaAtendimento.regional),
            _rota('3', 'Vila Nova'),
          ],
          clientes: [
            _cliente('a', 'Ana', '1'),
            _cliente('b', 'Beto', '1'),
            _cliente('c', 'Caio', '2'),
          ],
        ),
      );

      expect(find.text('Centro'), findsOneWidget);
      expect(find.text('Toledo · R-1'), findsOneWidget);
      expect(find.text('2 clientes'), findsOneWidget);
      expect(find.text('Regional · R-2'), findsOneWidget);
      expect(find.text('1 cliente'), findsOneWidget);
      expect(find.text('Nenhum cliente'), findsOneWidget);

      double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
      expect(y('Centro'), lessThan(y('Vila Nova')));
      expect(y('Vila Nova'), lessThan(y('Zona Sul')));
    });

    testWidgets('sem rotas mostra o EmptyState', (tester) async {
      await _abrir(tester);
      expect(find.text('Nenhuma rota cadastrada'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('busca sem acento e estado "nada encontrado"', (tester) async {
      await _abrir(
        tester,
        semente: _Semente(
          rotas: [_rota('1', 'São Cristóvão'), _rota('2', 'Centro')],
        ),
      );

      await tester.enterText(find.byType(TextField), 'sao crist');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('São Cristóvão'), findsOneWidget);
      expect(find.text('Centro'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nenhuma rota encontrada'), findsOneWidget);
    });

    testWidgets('a lista acompanha a criação em tempo real', (tester) async {
      final db = await _abrir(
        tester,
        semente: _Semente(rotas: [_rota('1', 'Centro')]),
      );
      await db.collection('rotas').doc('9').set(_rota('9', 'Nova').toMap());
      await tester.pump();
      await tester.pump();
      expect(find.text('Nova'), findsOneWidget);
    });

    testWidgets('erro mostra mensagem em vez de spinner', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotasAtivasProvider.overrideWith(
              (ref) => Stream.error(StateError('falhou')),
            ),
          ],
          child: const MaterialApp(home: RotasScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Erro ao carregar as rotas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('sem emissão mostra carregando e não quebra', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rotasAtivasProvider.overrideWith(
              (ref) => StreamController<List<RotaModel>>().stream,
            ),
          ],
          child: const MaterialApp(home: RotasScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('criar', () {
    testWidgets('formulário vazio mostra os erros e não grava', (tester) async {
      final db = await _abrir(tester);
      await tester.tap(find.text('Nova rota'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(find.text('Informe o nome da rota.'), findsOneWidget);
      expect(find.text('Escolha a linha de atendimento.'), findsOneWidget);
      expect((await db.collection('rotas').get()).docs, isEmpty);
    });

    testWidgets('nome duplicado (sem acento/caixa) é recusado', (tester) async {
      final db = await _abrir(
        tester,
        semente: _Semente(rotas: [_rota('1', 'São Cristóvão')]),
      );
      await tester.tap(find.text('Nova rota'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoNome(), 'SAO CRISTOVAO');
      await tester.tap(find.byType(DropdownButtonFormField<LinhaAtendimento>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toledo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Já existe uma rota com esse nome.'), findsOneWidget);
      expect((await db.collection('rotas').get()).docs, hasLength(1));
    });

    testWidgets('cria a rota, fecha o formulário e mostra na lista', (
      tester,
    ) async {
      final db = await _abrir(tester);
      await tester.tap(find.text('Nova rota'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoNome(), 'Zona Sul');
      await tester.tap(find.byType(DropdownButtonFormField<LinhaAtendimento>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regional').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Rota cadastrada.'), findsOneWidget);
      expect(find.byType(RotaFormSheet), findsNothing);
      final docs = (await db.collection('rotas').get()).docs;
      expect(docs.single.data()['nome'], 'Zona Sul');
      expect(docs.single.data()['linhaAtendimento'], 'regional');
      expect(find.text('Zona Sul'), findsOneWidget);
    });
  });

  group('detalhe, editar e excluir', () {
    final semente = _Semente(
      rotas: [_rota('1', 'Centro'), _rota('2', 'Vazia')],
      clientes: [_cliente('a', 'Zeca', '1'), _cliente('b', 'Ângela', '1')],
    );

    testWidgets('detalhe mostra dados, clientes em ordem e o botão '
        'Associar ligado (KAN-46)', (tester) async {
      await _abrir(tester, semente: semente);
      await tester.tap(find.text('Centro'));
      await tester.pumpAndSettle();

      expect(find.text('2 clientes'), findsWidgets);
      expect(find.text('Clientes da rota'), findsOneWidget);
      double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
      expect(y('Ângela'), lessThan(y('Zeca')));

      final associar = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Associar clientes'),
      );
      expect(associar.onPressed, isNotNull);
    });

    testWidgets('rota sem clientes mostra o EmptyState de clientes', (
      tester,
    ) async {
      await _abrir(tester, semente: semente);
      await tester.tap(find.text('Vazia'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum cliente nesta rota'), findsOneWidget);
    });

    testWidgets('editar muda só o nome e mantém o id (clientes seguem '
        'ligados)', (tester) async {
      final db = await _abrir(tester, semente: semente);
      await tester.tap(find.text('Centro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoNome(), 'Centro Norte');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final d = (await db.collection('rotas').doc('1').get()).data()!;
      expect(d['nome'], 'Centro Norte');
      expect(d['id'], '1');
      final cliente = (await db.collection('clientes').doc('a').get()).data()!;
      expect(cliente['rotaId'], '1');
      expect(find.text('2 clientes'), findsWidgets);
    });

    testWidgets('editar mantendo o próprio nome não acusa duplicado', (
      tester,
    ) async {
      await _abrir(tester, semente: semente);
      await tester.tap(find.text('Centro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(find.text('Já existe uma rota com esse nome.'), findsNothing);
    });

    testWidgets('excluir rota com clientes é bloqueado, com a mensagem', (
      tester,
    ) async {
      final db = await _abrir(tester, semente: semente);
      await tester.tap(find.text('Centro'));
      await tester.pumpAndSettle();

      // A regra já aparece no detalhe, antes de tocar em Excluir.
      expect(
        find.text('Remova ou mude os 2 clientes desta rota antes de excluir.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir rota'), findsNothing); // sem confirmação
      expect(
        (await db.collection('rotas').doc('1').get()).data()!['deleted'],
        false,
      );
    });

    testWidgets('excluir rota vazia pede confirmação e faz exclusão '
        'lógica', (tester) async {
      final db = await _abrir(tester, semente: semente);
      await tester.tap(find.text('Vazia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir rota'), findsOneWidget);

      // Cancelar não exclui.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('rotas').doc('2').get()).data()!['deleted'],
        false,
      );

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();

      final d = (await db.collection('rotas').doc('2').get()).data()!;
      expect(d['deleted'], true);
      expect(find.text('Rota excluída.'), findsOneWidget);
      expect(find.text('Vazia'), findsNothing);
    });
  });
}
