import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/providers/firebase_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/estoque_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/entrada_estoque_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/registrar_entrada_sheet.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 10);

ProdutoModel _produto({int estoque = 20, double custo = 4}) => ProdutoModel(
  id: 'p1',
  codigo: 'P-1',
  nome: 'Arroz',
  marca: 'Tio João',
  categoria: 'Grãos',
  preco: 10,
  custoAtual: custo,
  estoqueAtual: estoque,
  updatedAt: _t,
);

class _UsuarioFalso implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repositório que nunca confirma a escrita (como o batch sem conexão).
class _EstoqueSemConexao extends EstoqueRepository {
  _EstoqueSemConexao(super.db);

  @override
  Future<void> registrarEntrada(movimento) => Completer<void>().future;
}

Future<void> _abrir(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  String? produtoId = 'p1',
  EstoqueRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // A lista de produtos vem do mesmo banco falso.
  final itens = db
      .collection('produtos')
      .snapshots()
      .map(
        (s) => montarItensEstoque([
          for (final d in s.docs) ProdutoModel.fromMap(d.data()),
        ]),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        estoqueRepositoryProvider.overrideWithValue(
          repo ?? EstoqueRepository(db),
        ),
        usuarioLogadoProvider.overrideWith(
          (ref) => Stream.value(_UsuarioFalso()),
        ),
        itensEstoqueProvider.overrideWith((ref) => itens),
        movimentosDoProdutoProvider.overrideWith(
          (ref, id) => Stream.value(const []),
        ),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            // Como o AuthGate no app: mantém a sessão carregada.
            ref.watch(usuarioLogadoProvider);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      registrarEntradaSheet(context, produtoId: produtoId),
                  child: const Text('abrir'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Finder _campo(String rotulo) => find.widgetWithText(TextField, rotulo);

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('produtos').doc('p1').set(_produto().toMap());
  });

  group('notifier', () {
    ProviderContainer container({EstoqueRepository? repo}) {
      final c = ProviderContainer(
        overrides: [
          estoqueRepositoryProvider.overrideWithValue(
            repo ?? EstoqueRepository(db),
          ),
          usuarioLogadoProvider.overrideWith(
            (ref) => Stream.value(_UsuarioFalso()),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(usuarioLogadoProvider, (_, _) {});
      c.listen(registrarEntradaProvider, (_, _) {});
      return c;
    }

    test('grava a entrada e soma no produto', () async {
      final c = container();
      await c.read(usuarioLogadoProvider.future);
      final r = await c
          .read(registrarEntradaProvider.notifier)
          .registrar(
            produtoId: 'p1',
            quantidade: 8,
            custoUnitario: 5,
            data: DateTime.now(),
            observacao: 'NF 9',
          );
      expect(r.quantidade, 8);
      expect(r.sincronizado, isTrue);
      final p = (await db.collection('produtos').doc('p1').get()).data()!;
      expect(p['estoqueAtual'], 28);
      expect(p['custoAtual'], 5);
    });

    test('sem confirmação do servidor vira "salvo no aparelho"', () async {
      final c = container(repo: _EstoqueSemConexao(db));
      await c.read(usuarioLogadoProvider.future);
      final r = await c
          .read(registrarEntradaProvider.notifier)
          .registrar(
            produtoId: 'p1',
            quantidade: 1,
            custoUnitario: 1,
            data: DateTime.now(),
          );
      expect(r.sincronizado, isFalse);
      expect(c.read(registrarEntradaProvider).isLoading, isFalse);
    });

    test('erro de gravação vai para o estado e é repassado', () async {
      final c = container();
      await c.read(usuarioLogadoProvider.future);
      await expectLater(
        c
            .read(registrarEntradaProvider.notifier)
            .registrar(
              produtoId: 'inexistente',
              quantidade: 1,
              custoUnitario: 1,
              data: DateTime.now(),
            ),
        throwsA(anything),
      );
      expect(c.read(registrarEntradaProvider).hasError, isTrue);
    });

    test('quantidade ou custo inválidos não gravam', () async {
      final c = container();
      await c.read(usuarioLogadoProvider.future);
      await expectLater(
        c
            .read(registrarEntradaProvider.notifier)
            .registrar(
              produtoId: 'p1',
              quantidade: 0,
              custoUnitario: 1,
              data: DateTime.now(),
            ),
        throwsStateError,
      );
      expect((await db.collection('movimentosEstoque').get()).docs, isEmpty);
    });
  });

  group('sheet', () {
    testWidgets('mostra a prévia e usa o custo atual como padrão', (
      tester,
    ) async {
      await _abrir(tester, db);

      expect(find.text('Estoque: 20 → —'), findsOneWidget);
      expect(find.text('Custo: R\$ 4,00 → R\$ 4,00'), findsOneWidget);

      await tester.enterText(_campo('Quantidade'), '10');
      await tester.enterText(_campo('Custo unitário'), '5,50');
      await tester.pump();

      expect(find.text('Estoque: 20 → 30'), findsOneWidget);
      expect(find.text('Custo: R\$ 4,00 → R\$ 5,50'), findsOneWidget);
    });

    testWidgets('confirmar vazio mostra os erros e não grava', (tester) async {
      await _abrir(tester, db);
      await tester.tap(find.text('Confirmar entrada'));
      await tester.pump();

      expect(find.text('Informe a quantidade.'), findsOneWidget);
      expect((await db.collection('movimentosEstoque').get()).docs, isEmpty);
    });

    testWidgets('quantidade zero e decimal mostram mensagem', (tester) async {
      await _abrir(tester, db);
      await tester.enterText(_campo('Quantidade'), '0');
      await tester.pump();
      expect(
        find.text('A quantidade deve ser maior que zero.'),
        findsOneWidget,
      );

      await tester.enterText(_campo('Quantidade'), '1,5');
      await tester.pump();
      expect(
        find.text('A quantidade deve ser um número inteiro.'),
        findsOneWidget,
      );
    });

    testWidgets('custo zero mostra mensagem', (tester) async {
      await _abrir(tester, db);
      await tester.enterText(_campo('Custo unitário'), '0');
      await tester.pump();
      expect(
        find.text('O custo unitário deve ser maior que zero.'),
        findsOneWidget,
      );
    });

    testWidgets('saldo negativo mostra aviso com o saldo resultante', (
      tester,
    ) async {
      await db
          .collection('produtos')
          .doc('p1')
          .set(_produto(estoque: -4).toMap());
      await _abrir(tester, db);
      await tester.enterText(_campo('Quantidade'), '10');
      await tester.pump();

      expect(
        find.textContaining('saldo atual está negativo (-4)'),
        findsOneWidget,
      );
      expect(find.textContaining('o saldo será 6'), findsOneWidget);
    });

    testWidgets('confirmar grava, fecha e mostra o SnackBar', (tester) async {
      await _abrir(tester, db);
      await tester.enterText(_campo('Quantidade'), '12');
      await tester.enterText(_campo('Observação (opcional)'), 'Fornecedor X');
      await tester.pump();
      await tester.tap(find.text('Confirmar entrada'));
      await tester.pumpAndSettle();

      expect(find.text('Entrada registrada: +12 un.'), findsOneWidget);
      expect(find.text('Confirmar entrada'), findsNothing);

      final movs = (await db.collection('movimentosEstoque').get()).docs;
      expect(movs.single.data()['observacao'], 'Fornecedor X');
      final p = (await db.collection('produtos').doc('p1').get()).data()!;
      expect(p['estoqueAtual'], 32);
    });

    testWidgets('erro de gravação mostra mensagem e mantém o sheet', (
      tester,
    ) async {
      await db.collection('produtos').doc('p1').delete();
      await db.collection('produtos').doc('p2').set({
        ..._produto().toMap(),
        'id': 'p2',
      });
      await _abrir(tester, db, produtoId: 'p2', repo: _EstoqueQueFalha(db));
      await tester.enterText(_campo('Quantidade'), '3');
      await tester.pump();
      await tester.tap(find.text('Confirmar entrada'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível registrar a entrada. Tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Confirmar entrada'), findsOneWidget);
    });

    testWidgets('sem produto escolhido, busca e seleciona', (tester) async {
      await db.collection('produtos').doc('p2').set({
        ..._produto().toMap(),
        'id': 'p2',
        'codigo': 'P-2',
        'nome': 'Feijão',
        'nomeBusca': 'feijão',
      });
      await _abrir(tester, db, produtoId: null);

      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('Feijão'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'feijao');
      await tester.pump();
      expect(find.text('Arroz'), findsNothing);

      await tester.tap(find.text('Feijão'));
      await tester.pumpAndSettle();
      expect(find.text('Quantidade'), findsOneWidget);
      expect(find.text('Trocar produto'), findsOneWidget);
    });
  });

  testWidgets('tela Estoque tem o botão Registrar entrada', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itensEstoqueProvider.overrideWith(
            (ref) => Stream.value(montarItensEstoque([_produto()])),
          ),
        ],
        child: const MaterialApp(home: EstoqueScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Registrar entrada'), findsOneWidget);
  });
}

class _EstoqueQueFalha extends EstoqueRepository {
  _EstoqueQueFalha(super.db);

  @override
  Future<void> registrarEntrada(movimento) =>
      Future.error(StateError('falhou'));
}
