import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'cliente_model.dart';

class ClienteRepository {
  ClienteRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('clientes');

  Future<void> salvar(ClienteModel cliente) =>
      _col.doc(cliente.id).set(cliente.toMap());

  Future<ClienteModel?> buscarPorId(String id) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    final cliente = ClienteModel.fromMap(data);
    return cliente.deleted ? null : cliente;
  }

  Stream<List<ClienteModel>> observarTodos() => _col
      .where('deleted', isEqualTo: false)
      .orderBy('nomeBusca')
      .snapshots()
      .map((s) => s.docs.map((d) => ClienteModel.fromMap(d.data())).toList());

  /// Busca por prefixo do nome (RF02), via campo nomeBusca.
  Stream<List<ClienteModel>> buscarPorNome(String termo) {
    final buscado = termo.toLowerCase();
    return _col
        .where('deleted', isEqualTo: false)
        .where('nomeBusca', isGreaterThanOrEqualTo: buscado)
        .where('nomeBusca', isLessThan: '$buscado')
        .snapshots()
        .map((s) => s.docs.map((d) => ClienteModel.fromMap(d.data())).toList());
  }

  Stream<List<ClienteModel>> observarPorRota(String rotaId) => _col
      .where('deleted', isEqualTo: false)
      .where('rotaId', isEqualTo: rotaId)
      .snapshots()
      .map((s) => s.docs.map((d) => ClienteModel.fromMap(d.data())).toList());

  /// Clientes com parcela em aberto vencendo até [ate] (RF09).
  Stream<List<ClienteModel>> observarAVisitar(DateTime ate) => _col
      .where('deleted', isEqualTo: false)
      .where('valorEmAberto', isGreaterThan: 0)
      .where('proximoVencimento', isLessThanOrEqualTo: ate.toIso8601String())
      .orderBy('proximoVencimento')
      .snapshots()
      .map((s) => s.docs.map((d) => ClienteModel.fromMap(d.data())).toList());

  Future<void> remover(String id) => _col.doc(id).update({
    'deleted': true,
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(ref.watch(firestoreProvider));
});
