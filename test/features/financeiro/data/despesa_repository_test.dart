import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

DespesaModel _despesa(
  String id, {
  String vendedorUid = 'u1',
  required DateTime data,
  double valor = 50,
  bool deleted = false,
}) => DespesaModel(
  id: id,
  vendedorUid: vendedorUid,
  descricao: 'Despesa $id',
  valor: valor,
  data: data,
  updatedAt: data,
  deleted: deleted,
);

void main() {
  late FakeFirebaseFirestore db;
  late DespesaRepository repo;

  final de = DateTime(2026, 11, 18);
  final ate = DateTime(2026, 11, 19);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = DespesaRepository(db);
  });

  test('lista as despesas do vendedor no dia, recente primeiro', () async {
    await repo.salvar(_despesa('manha', data: DateTime(2026, 11, 18, 8)));
    await repo.salvar(_despesa('tarde', data: DateTime(2026, 11, 18, 17)));
    await repo.salvar(_despesa('ontem', data: DateTime(2026, 11, 17, 20)));
    await repo.salvar(_despesa('amanha', data: DateTime(2026, 11, 19)));
    await repo.salvar(
      _despesa('outro', vendedorUid: 'u2', data: DateTime(2026, 11, 18, 9)),
    );

    final lista = await repo.observarDoVendedor('u1', de: de, ate: ate).first;

    expect(lista.map((d) => d.id), ['tarde', 'manha']);
  });

  test('remover faz exclusão lógica e some da lista', () async {
    await repo.salvar(_despesa('d1', data: DateTime(2026, 11, 18, 10)));

    await repo.remover('d1');

    final doc = (await db.collection('despesas').doc('d1').get()).data()!;
    expect(doc['deleted'], isTrue);
    final lista = await repo.observarDoVendedor('u1', de: de, ate: ate).first;
    expect(lista, isEmpty);
  });

  test('salvar de novo com o mesmo id atualiza a despesa', () async {
    final original = _despesa('d1', data: DateTime(2026, 11, 18, 10));
    await repo.salvar(original);

    await repo.salvar(original.copyWith(valor: 80, descricao: 'Pedágio'));

    final lista = await repo.observarDoVendedor('u1', de: de, ate: ate).first;
    expect(lista.single.valor, 80);
    expect(lista.single.descricao, 'Pedágio');
  });
}