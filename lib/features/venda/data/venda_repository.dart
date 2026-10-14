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
  CollectionReference<Map<String, dynamic>> get _produtos =>
      _db.collection('produtos');

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

    _gravarMovimentos(lote, movimentos);

    lote.set(_clientes.doc(clienteAtualizado.id), clienteAtualizado.toMap());

    await lote.commit();
  }

  /// Registra a troca de um item em venda já concluída (RF25, KAN-28):
  /// acrescenta a troca à venda, atualiza a observação (RF26) e grava os
  /// movimentos de estoque (devolução do original e saída do novo).
  ///
  /// A troca entra com arrayUnion, e não reescrevendo a lista inteira:
  /// duas trocas feitas offline na mesma venda não se sobrescrevem.
  Future<void> registrarTroca({
    required String vendaId,
    required TrocaItem troca,
    required String observacao,
    required List<MovimentoEstoqueModel> movimentos,
  }) async {
    final lote = _db.batch();
    lote.update(_vendas.doc(vendaId), {
      'trocas': FieldValue.arrayUnion([troca.toMap()]),
      'observacao': observacao,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _gravarMovimentos(lote, movimentos);
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

  /// Venda por id, atualizada em tempo real. `null` se não existe ou foi
  /// removida.
  Stream<VendaModel?> observarPorId(String id) =>
      _vendas.doc(id).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) return null;
        final venda = VendaModel.fromMap(data);
        return venda.deleted ? null : venda;
      });

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

  /// Grava cada movimento e ajusta o cache `estoqueAtual` do produto.
  ///
  /// O ajuste usa FieldValue.increment, que soma no servidor: dois
  /// vendedores vendendo o mesmo produto offline não perdem a baixa um
  /// do outro (ADR 001). O saldo autoritativo continua sendo a soma dos
  /// movimentos.
  void _gravarMovimentos(
    WriteBatch lote,
    List<MovimentoEstoqueModel> movimentos,
  ) {
    for (final m in movimentos) {
      lote.set(_movimentos.doc(m.id), m.toMap());
      lote.update(_produtos.doc(m.produtoId), {
        'estoqueAtual': FieldValue.increment(m.delta),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }
}

final vendaRepositoryProvider = Provider<VendaRepository>((ref) {
  return VendaRepository(ref.watch(firestoreProvider));
});
