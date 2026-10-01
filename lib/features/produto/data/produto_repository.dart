import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'produto_model.dart';

class ProdutoRepository {
  ProdutoRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('produtos');

  Future<void> salvar(ProdutoModel produto) =>
      _col.doc(produto.id).set(produto.toMap());

  Stream<List<ProdutoModel>> observarTodos() => _col
      .where('deleted', isEqualTo: false)
      .orderBy('nomeBusca')
      .snapshots()
      .map((s) => s.docs.map((d) => ProdutoModel.fromMap(d.data())).toList());

  Stream<List<ProdutoModel>> observarPorCategoria(String categoria) => _col
      .where('deleted', isEqualTo: false)
      .where('categoria', isEqualTo: categoria)
      .snapshots()
      .map((s) => s.docs.map((d) => ProdutoModel.fromMap(d.data())).toList());

  Future<ProdutoModel?> buscarPorId(String id) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    final produto = ProdutoModel.fromMap(data);
    return produto.deleted ? null : produto;
  }

  Future<void> remover(String id) => _col.doc(id).update({
    'deleted': true,
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

final produtoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(ref.watch(firestoreProvider));
});
