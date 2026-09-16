import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../cliente/data/cliente_model.dart';
import '../../estoque/data/movimento_estoque_model.dart';
import 'parcela_model.dart';
import 'venda_model.dart';

class VendaRepository {
  VendaRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _vendas =>
      _db.collection('vendas');
  CollectionReference<Map<String, dynamic>> get _clientes =>
      _db.collection('clientes');
  CollectionReference<Map<String, dynamic>> get _movimentos =>
      _db.collection('movimentosEstoque');

  CollectionReference<Map<String, dynamic>> _parcelas(String vendaId) =>
      _vendas.doc(vendaId).collection('parcelas');

  /// Registra venda, parcelas, baixa de estoque e atualização do cliente
  /// em uma única operação atômica (modelo lógico, seção 6).
  Future<void> registrarVenda({
    required VendaModel venda,
    required List<ParcelaModel> parcelas,
    required List<MovimentoEstoqueModel> movimentos,
    required ClienteModel clienteAtualizado,
  }) async {
    final lote = _db.batch();

    lote.set(_vendas.doc(venda.id), venda.toMap());

    for (final p in parcelas) {
      lote.set(_parcelas(venda.id).doc(p.id), p.toMap());
    }

    for (final m in movimentos) {
      lote.set(_movimentos.doc(m.id), m.toMap());
    }

    lote.set(_clientes.doc(clienteAtualizado.id), clienteAtualizado.toMap());

    await lote.commit();
  }

  /// Quita ou registra pagamento parcial, atualizando o cliente.
  Future<void> registrarPagamento({
    required ParcelaModel parcela,
    required ClienteModel clienteAtualizado,
  }) async {
    final lote = _db.batch();
    lote.set(_parcelas(parcela.vendaId).doc(parcela.id), parcela.toMap());
    lote.set(_clientes.doc(clienteAtualizado.id), clienteAtualizado.toMap());
    await lote.commit();
  }

  Stream<List<VendaModel>> observarPorCliente(String clienteId) => _vendas
      .where('deleted', isEqualTo: false)
      .where('clienteId', isEqualTo: clienteId)
      .orderBy('data', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => VendaModel.fromMap(d.data())).toList());

  Stream<List<VendaModel>> observarPorPeriodo(DateTime de, DateTime ate) =>
      _vendas
          .where('deleted', isEqualTo: false)
          .where('data', isGreaterThanOrEqualTo: de.toIso8601String())
          .where('data', isLessThanOrEqualTo: ate.toIso8601String())
          .snapshots()
          .map((s) => s.docs.map((d) => VendaModel.fromMap(d.data())).toList());

  Stream<List<ParcelaModel>> observarParcelas(String vendaId) =>
      _parcelas(vendaId)
          .where('deleted', isEqualTo: false)
          .orderBy('numero')
          .snapshots()
          .map(
            (s) => s.docs.map((d) => ParcelaModel.fromMap(d.data())).toList(),
          );
}

final vendaRepositoryProvider = Provider<VendaRepository>((ref) {
  return VendaRepository(ref.watch(firestoreProvider));
});
