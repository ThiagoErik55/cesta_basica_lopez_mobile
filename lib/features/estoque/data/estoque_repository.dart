import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import 'movimento_estoque_model.dart';

class EstoqueRepository {
  EstoqueRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('movimentosEstoque');

  CollectionReference<Map<String, dynamic>> get _produtos =>
      _db.collection('produtos');

  /// Registra uma entrada de estoque (KAN-42) em um único batch, que
  /// funciona offline:
  ///
  /// - cria o movimento de entrada;
  /// - soma a quantidade em `produtos/{id}.estoqueAtual` com
  ///   `FieldValue.increment` (duas entradas ou uma venda offline não
  ///   perdem a soma uma da outra, ADR 001);
  /// - grava o custo da última compra em `custoAtual` e `updatedAt`.
  ///
  /// Atualiza só esses campos do produto, sem regravá-lo por inteiro. O
  /// produto precisa existir: o `update` do batch falha se ele não existe.
  Future<void> registrarEntrada(MovimentoEstoqueModel entrada) {
    assert(entrada.tipo == TipoMovimento.entrada);
    assert(entrada.custoUnitario != null);
    final lote = _db.batch();
    lote.set(_col.doc(entrada.id), entrada.toMap());
    lote.update(_produtos.doc(entrada.produtoId), {
      'estoqueAtual': FieldValue.increment(entrada.quantidade),
      'custoAtual': entrada.custoUnitario,
      'updatedAt': entrada.updatedAt.toIso8601String(),
    });
    return lote.commit();
  }

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
