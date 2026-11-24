import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'despesa_model.dart';


class DespesaRepository {
  DespesaRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('despesas');


  Future<void> salvar(DespesaModel despesa) =>
      _col.doc(despesa.id).set(despesa.toMap());


  Future<void> remover(String id) => _col.doc(id).update({
    'deleted': true,
    'updatedAt': DateTime.now().toIso8601String(),
  });

  
  Stream<List<DespesaModel>> observarDoVendedor(
    String vendedorUid, {
    required DateTime de,
    required DateTime ate,
  }) => _consulta(
    vendedorUid,
  ).snapshots().map((s) => _filtrar(s, de: de, ate: ate));

 
  Future<List<DespesaModel>> doVendedorEmCache(
    String vendedorUid, {
    required DateTime de,
    required DateTime ate,
  }) async => _filtrar(
    await _consulta(vendedorUid).get(const GetOptions(source: Source.cache)),
    de: de,
    ate: ate,
  );

  Query<Map<String, dynamic>> _consulta(String vendedorUid) =>
      _col.where('vendedorUid', isEqualTo: vendedorUid);

  List<DespesaModel> _filtrar(
    QuerySnapshot<Map<String, dynamic>> s, {
    required DateTime de,
    required DateTime ate,
  }) {
    final lista = s.docs
        .map((d) => DespesaModel.fromMap(d.data()))
        .where(
          (d) => !d.deleted && !d.data.isBefore(de) && d.data.isBefore(ate),
        )
        .toList();
    lista.sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }
}

final despesaRepositoryProvider = Provider<DespesaRepository>((ref) {
  return DespesaRepository(ref.watch(firestoreProvider));
});