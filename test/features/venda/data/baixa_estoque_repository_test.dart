import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/movimento_estoque_model.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/atualizacao_cliente.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 11, 10);

ProdutoModel _produto(String id, int estoque, double custo) => ProdutoModel(
  id: id,
  codigo: 'P-$id',
  nome: 'Produto $id',
  marca: 'M',
  categoria: 'C',
  preco: 20,
  custoAtual: custo,
  estoqueAtual: estoque,
  updatedAt: DateTime(2026, 11, 1),
);

MovimentoEstoqueModel _saida(
  String id,
  String produtoId,
  int qtd,
  double custo,
) => MovimentoEstoqueModel(
  id: id,
  produtoId: produtoId,
  vendaId: 'v1',
  tipo: TipoMovimento.saida,
  quantidade: qtd,
  data: _agora,
  vendedorUid: 'u1',
  custoUnitario: custo,
  updatedAt: _agora,
);

VendaModel _venda(List<ItemVenda> itens) => VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: _agora,
  itens: itens,
  valorTotal: 200,
  tipo: TipoVenda.parcelado,
  updatedAt: _agora,
);

ParcelaModel _parcela(int n) => ParcelaModel(
  id: 'pc$n',
  vendaId: 'v1',
  numero: n,
  valor: 100,
  vencimento: DateTime(2026, 12, n),
  updatedAt: _agora,
);

void main() {
  late FakeFirebaseFirestore db;
  late VendaRepository repo;

  Future<Map<String, dynamic>> doc(String caminho) async =>
      (await db.doc(caminho).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VendaRepository(db);
    await db.collection('produtos').doc('a').set(_produto('a', 20, 5).toMap());
    await db.collection('produtos').doc('b').set(_produto('b', 10, 8).toMap());
    await db
        .collection('clientes')
        .doc('c1')
        .set(
          ClienteModel(
            id: 'c1',
            codigo: 'C-1',
            nome: 'Maria',
            cpf: '529.982.247-25',
            telefone: '1',
            endereco: 'Rua A',
            updatedAt: _agora,
          ).toMap(),
        );
  });

  test('venda com 2 produtos e 1 repetido: movimentos e baixas no mesmo '
      'batch da venda e das parcelas', () async {
    final itens = [
      const ItemVenda(
        id: 'i1',
        produtoId: 'a',
        nome: 'Produto a',
        quantidade: 2,
        precoUnitario: 20,
        custoUnitario: 5,
      ),
      const ItemVenda(
        id: 'i2',
        produtoId: 'b',
        nome: 'Produto b',
        quantidade: 3,
        precoUnitario: 20,
        custoUnitario: 8,
      ),
      const ItemVenda(
        id: 'i3',
        produtoId: 'a',
        nome: 'Produto a',
        quantidade: 4,
        precoUnitario: 20,
        custoUnitario: 5,
      ),
    ];

    await repo.registrarVenda(
      venda: _venda(itens),
      parcelas: [_parcela(1), _parcela(2)],
      movimentos: [
        _saida('m1', 'a', 2, 5),
        _saida('m2', 'b', 3, 8),
        _saida('m3', 'a', 4, 5),
      ],
      cliente: AtualizacaoClienteVenda(
        clienteId: 'c1',
        ultimaCompra: _agora,
        acrescimoEmAberto: 200,
      ),
    );

    // Venda, itens e parcelas gravados junto.
    expect((await doc('vendas/v1'))['itens'], hasLength(3));
    expect((await db.collection('vendas/v1/parcelas').get()).docs.length, 2);

    // Um movimento de saída por item, ligado à venda.
    final movs = (await db.collection('movimentosEstoque').get()).docs
        .map((d) => d.data())
        .toList();
    expect(movs, hasLength(3));
    for (final m in movs) {
      expect(m['tipo'], 'saida');
      expect(m['vendaId'], 'v1');
    }

    // Baixa soma, sem sobrescrever: a = 20 - (2 + 4), b = 10 - 3.
    expect((await doc('produtos/a'))['estoqueAtual'], 14);
    expect((await doc('produtos/b'))['estoqueAtual'], 7);

    // A venda não mexe em mais nada do produto.
    expect((await doc('produtos/a'))['custoAtual'], 5);
    expect((await doc('produtos/a'))['preco'], 20);

    // O cliente também foi atualizado no mesmo batch.
    expect((await doc('clientes/c1'))['valorEmAberto'], 200);
  });

  test('custoUnitario da saída é o custo do produto, não o preço', () async {
    await repo.registrarVenda(
      venda: _venda(const []),
      parcelas: const [],
      movimentos: [_saida('m1', 'a', 1, 5)],
      cliente: AtualizacaoClienteVenda(clienteId: 'c1', ultimaCompra: _agora),
    );
    final mov = await doc('movimentosEstoque/m1');
    expect(mov['custoUnitario'], 5);
    expect(mov['custoUnitario'], isNot(20));
  });

  test('venda acima do estoque deixa o saldo negativo', () async {
    await repo.registrarVenda(
      venda: _venda(const []),
      parcelas: const [],
      movimentos: [_saida('m1', 'b', 13, 8)],
      cliente: AtualizacaoClienteVenda(clienteId: 'c1', ultimaCompra: _agora),
    );
    expect((await doc('produtos/b'))['estoqueAtual'], -3);
  });

  test('movimento repetido com o mesmo id não duplica o documento', () async {
    final m = _saida('m1', 'a', 1, 5);
    for (var i = 0; i < 2; i++) {
      await db.collection('movimentosEstoque').doc(m.id).set(m.toMap());
    }
    expect((await db.collection('movimentosEstoque').get()).docs.length, 1);
  });

  test('troca ajusta dois movimentos: devolvido volta e novo sai', () async {
    await db
        .collection('vendas')
        .doc('v1')
        .set(
          _venda(const [
            ItemVenda(
              id: 'i1',
              produtoId: 'a',
              nome: 'Produto a',
              quantidade: 5,
              precoUnitario: 20,
              custoUnitario: 5,
            ),
          ]).toMap(),
        );

    await repo.registrarTroca(
      vendaId: 'v1',
      troca: TrocaItem(
        id: 't1',
        itemOriginalId: 'i1',
        produtoNovoId: 'b',
        produtoNovoNome: 'Produto b',
        quantidade: 2,
        data: _agora,
      ),
      observacao: 'Troca realizada',
      movimentos: [
        MovimentoEstoqueModel(
          id: 'mt1',
          produtoId: 'a',
          vendaId: 'v1',
          tipo: TipoMovimento.entrada,
          quantidade: 2,
          data: _agora,
          vendedorUid: 'u1',
          updatedAt: _agora,
        ),
        MovimentoEstoqueModel(
          id: 'mt2',
          produtoId: 'b',
          vendaId: 'v1',
          tipo: TipoMovimento.troca,
          quantidade: 2,
          data: _agora,
          vendedorUid: 'u1',
          updatedAt: _agora,
        ),
      ],
    );

    expect((await db.collection('movimentosEstoque').get()).docs.length, 2);
    expect((await doc('produtos/a'))['estoqueAtual'], 22);
    expect((await doc('produtos/b'))['estoqueAtual'], 8);
    expect((await doc('vendas/v1'))['trocas'], hasLength(1));
  });
}
