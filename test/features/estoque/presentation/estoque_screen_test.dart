import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/movimento_estoque_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 10);

ProdutoModel _p(String id, String nome, int estoque) => ProdutoModel(
  id: id,
  codigo: 'P-$id',
  nome: nome,
  marca: 'Marca',
  categoria: 'Grãos',
  preco: 10,
  custoAtual: 5,
  estoqueAtual: estoque,
  updatedAt: _t,
);

Future<void> _abrir(
  WidgetTester tester, {
  required Stream<List<ItemEstoque>> itens,
  Stream<List<MovimentoEstoqueModel>>? movimentos,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itensEstoqueProvider.overrideWith((ref) => itens),
        movimentosDoProdutoProvider.overrideWith(
          (ref, id) => movimentos ?? Stream.value(const []),
        ),
      ],
      child: const MaterialApp(home: EstoqueScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('lista com resumo, selos e ordem: sem estoque primeiro', (
    tester,
  ) async {
    await _abrir(
      tester,
      itens: Stream.value(
        montarItensEstoque([
          _p('a', 'Arroz', 50),
          _p('b', 'Feijão', -2),
          _p('c', 'Açúcar', 3),
        ]),
      ),
    );
    await tester.pump();

    expect(find.text('Valor em estoque'), findsOneWidget);
    expect(find.text('NEGATIVO'), findsOneWidget);
    expect(find.text('ESTOQUE BAIXO'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);

    double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
    expect(y('Feijão'), lessThan(y('Açúcar')));
    expect(y('Açúcar'), lessThan(y('Arroz')));
  });

  testWidgets('busca sem acento e estado "nada encontrado"', (tester) async {
    await _abrir(
      tester,
      itens: Stream.value(
        montarItensEstoque([_p('a', 'Arroz', 50), _p('c', 'Açúcar', 3)]),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'acucar');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Açúcar'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nenhum produto encontrado'), findsOneWidget);
  });

  testWidgets('lista vazia mostra EmptyState', (tester) async {
    await _abrir(tester, itens: Stream.value(const []));
    await tester.pump();
    expect(find.text('Nenhum produto cadastrado'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem em vez de spinner', (tester) async {
    await _abrir(tester, itens: Stream.error(StateError('falhou')));
    await tester.pump();
    expect(find.text('Erro ao carregar o estoque'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('detalhe lista movimentações e deixa "Registrar entrada" '
      'desabilitado', (tester) async {
    await _abrir(
      tester,
      itens: Stream.value(montarItensEstoque([_p('a', 'Arroz', 50)])),
      movimentos: Stream.value([
        MovimentoEstoqueModel(
          id: 'm1',
          produtoId: 'a',
          tipo: TipoMovimento.entrada,
          quantidade: 30,
          data: DateTime(2026, 11, 5, 9),
          vendedorUid: 'u',
          custoUnitario: 4.5,
          updatedAt: _t,
        ),
      ]),
    );
    await tester.pump();

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Movimentações'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    final botao = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(botao.onPressed, isNull);
  });

  testWidgets('detalhe sem movimentações mostra EmptyState', (tester) async {
    await _abrir(
      tester,
      itens: Stream.value(montarItensEstoque([_p('a', 'Arroz', 50)])),
    );
    await tester.pump();
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma movimentação'), findsOneWidget);
  });
}
