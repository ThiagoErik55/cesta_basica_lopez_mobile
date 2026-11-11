import 'package:cesta_basica_lopez_mobile/features/estoque/data/estoque_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/entrada_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 11, 10);

ProdutoModel _produto({int estoque = 20}) => ProdutoModel(
  id: 'p1',
  codigo: 'P-1',
  nome: 'Arroz',
  marca: 'Tio João',
  categoria: 'Grãos',
  preco: 10,
  custoAtual: 4,
  estoqueAtual: estoque,
  estoqueMinimo: 10,
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  late FakeFirebaseFirestore db;
  late EstoqueRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = EstoqueRepository(db);
  });

  Future<void> semear({int estoque = 20}) => db
      .collection('produtos')
      .doc('p1')
      .set(_produto(estoque: estoque).toMap());

  test('grava o movimento e atualiza só estoque, custo e updatedAt', () async {
    await semear();
    final antes = (await db.collection('produtos').doc('p1').get()).data()!;

    final entrada = montarMovimentoEntrada(
      id: 'm1',
      produtoId: 'p1',
      quantidade: 15,
      custoUnitario: 5.5,
      data: DateTime(2026, 11, 10),
      vendedorUid: 'u1',
      observacao: 'NF 123',
      agora: _agora,
    );
    await repo.registrarEntrada(entrada);

    final mov = (await db.collection('movimentosEstoque').doc('m1').get())
        .data()!;
    expect(mov['tipo'], 'entrada');
    expect(mov['produtoId'], 'p1');
    expect(mov['quantidade'], 15);
    expect(mov['custoUnitario'], 5.5);
    expect(mov['observacao'], 'NF 123');
    expect(mov['vendedorUid'], 'u1');
    expect(mov['vendaId'], isNull);
    expect(mov['deleted'], false);
    expect((await db.collection('movimentosEstoque').get()).docs.length, 1);

    final depois = (await db.collection('produtos').doc('p1').get()).data()!;
    expect(depois['estoqueAtual'], 35);
    expect(depois['custoAtual'], 5.5);
    expect(depois['updatedAt'], _agora.toIso8601String());

    // Nada além desses três campos mudou.
    final mudaram = {
      for (final k in {...antes.keys, ...depois.keys})
        if (antes[k] != depois[k]) k,
    };
    expect(mudaram, {'estoqueAtual', 'custoAtual', 'updatedAt'});
  });

  test('entrada sobre saldo negativo soma normalmente', () async {
    await semear(estoque: -4);
    await repo.registrarEntrada(
      montarMovimentoEntrada(
        id: 'm1',
        produtoId: 'p1',
        quantidade: 10,
        custoUnitario: 4,
        data: _agora,
        vendedorUid: 'u1',
        agora: _agora,
      ),
    );
    final p = (await db.collection('produtos').doc('p1').get()).data()!;
    expect(p['estoqueAtual'], 6);
  });

  test('duas entradas acumulam e o último custo prevalece', () async {
    await semear(estoque: 0);
    for (final (id, qtd, custo) in [('m1', 5, 3.0), ('m2', 7, 6.0)]) {
      await repo.registrarEntrada(
        montarMovimentoEntrada(
          id: id,
          produtoId: 'p1',
          quantidade: qtd,
          custoUnitario: custo,
          data: _agora,
          vendedorUid: 'u1',
          agora: _agora,
        ),
      );
    }
    final p = (await db.collection('produtos').doc('p1').get()).data()!;
    expect(p['estoqueAtual'], 12);
    expect(p['custoAtual'], 6);
    final soma = (await repo.observarSaldo('p1').first);
    expect(soma, 12);
  });

  test('observação em branco não grava o campo', () async {
    await semear();
    await repo.registrarEntrada(
      montarMovimentoEntrada(
        id: 'm1',
        produtoId: 'p1',
        quantidade: 1,
        custoUnitario: 1,
        data: _agora,
        vendedorUid: 'u1',
        agora: _agora,
      ),
    );
    final mov = (await db.collection('movimentosEstoque').doc('m1').get())
        .data()!;
    expect(mov.containsKey('observacao'), isFalse);
  });

  test('produto inexistente faz o batch falhar', () async {
    final entrada = montarMovimentoEntrada(
      id: 'm1',
      produtoId: 'fantasma',
      quantidade: 1,
      custoUnitario: 1,
      data: _agora,
      vendedorUid: 'u1',
      agora: _agora,
    );
    await expectLater(repo.registrarEntrada(entrada), throwsA(anything));
  });
}
