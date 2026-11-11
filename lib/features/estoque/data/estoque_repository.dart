import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'movimento_estoque_model.dart';

class EstoqueRepository {
  EstoqueRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('movimentosEstoque');

  Future<void> registrar(MovimentoEstoqueModel movimento) =>
      _col.doc(movimento.id).set(movimento.toMap());

  Stream<List<MovimentoEstoqueModel>> observarPorProduto(String produtoId) =>
      _col
          .where('deleted', isEqualTo: false)
          .where('produtoId', isEqualTo: produtoId)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => MovimentoEstoqueModel.fromMap(d.data()))
                .toList(),
          );

  /// Movimentos do produto só do cache local, para quando o servidor
  /// não responde a tempo.
  Future<List<MovimentoEstoqueModel>> movimentosEmCache(
    String produtoId,
  ) async {
    final s = await _col
        .where('deleted', isEqualTo: false)
        .where('produtoId', isEqualTo: produtoId)
        .get(const GetOptions(source: Source.cache));
    return [for (final d in s.docs) MovimentoEstoqueModel.fromMap(d.data())];
  }

  /// Saldo derivado dos movimentos — fonte autoritativa (ADR 001).
  Stream<int> observarSaldo(String produtoId) =>
      observarPorProduto(produtoId)
          .map((movs) => movs.fold<int>(0, (soma, m) => soma + m.delta));
}

final estoqueRepositoryProvider = Provider<EstoqueRepository>((ref) {
  return EstoqueRepository(ref.watch(firestoreProvider));
});
