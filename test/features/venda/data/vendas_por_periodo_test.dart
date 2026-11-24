import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

VendaModel _venda(String id, DateTime data, {bool deleted = false}) =>
    VendaModel(
      id: id,
      clienteId: 'c1',
      clienteNome: 'Maria',
      vendedorUid: 'u1',
      numeroNota: 1,
      data: data,
      itens: const [],
      valorTotal: 100,
      tipo: TipoVenda.aVista,
      updatedAt: data,
      deleted: deleted,
    );

void main() {
  test('observarPorPeriodo traz só as vendas ativas do dia', () async {
    final db = FakeFirebaseFirestore();
    final repo = VendaRepository(db);
    Future<void> semear(VendaModel v) =>
        db.collection('vendas').doc(v.id).set(v.toMap());

    await semear(_venda('inicio', DateTime(2026, 11, 18)));
    await semear(_venda('tarde', DateTime(2026, 11, 18, 16, 30, 12, 345)));
    await semear(_venda('ontem', DateTime(2026, 11, 17, 23, 59)));
    await semear(_venda('amanha', DateTime(2026, 11, 19)));
    await semear(
      _venda('excluida', DateTime(2026, 11, 18, 12), deleted: true),
    );

    final vendas = await repo
        .observarPorPeriodo(DateTime(2026, 11, 18), DateTime(2026, 11, 19))
        .first;

    expect(vendas.map((v) => v.id).toSet(), {'inicio', 'tarde'});
  });
}