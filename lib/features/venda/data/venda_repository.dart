import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../estoque/data/movimento_estoque_model.dart';
import '../domain/alteracao_parcela.dart';
import '../domain/atualizacao_cliente.dart';
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
    required AtualizacaoClienteVenda cliente,
  }) async {
    final lote = _db.batch();

    lote.set(_vendas.doc(venda.id), venda.toMap());

    for (final p in parcelas) {
      lote.set(_parcelas(venda.id).doc(p.id), p.toMap());
    }

    _gravarMovimentos(lote, movimentos);

    _atualizarCliente(lote, cliente);

    await lote.commit();
  }

  /// Atualiza só os campos que a venda altera. O valor em aberto soma no
  /// servidor (FieldValue.increment), então duas vendas parceladas feitas
  /// offline para o mesmo cliente não perdem o débito uma da outra.
  void _atualizarCliente(WriteBatch lote, AtualizacaoClienteVenda c) {
    final agora = DateTime.now().toIso8601String();
    lote.update(_clientes.doc(c.clienteId), {
      if (c.ultimaCompra != null)
        'ultimaCompra': c.ultimaCompra!.toIso8601String(),
      if (c.acrescimoEmAberto != 0)
        'valorEmAberto': FieldValue.increment(c.acrescimoEmAberto),
      if (c.proximoVencimento != null)
        'proximoVencimento': c.proximoVencimento!.toIso8601String()
      else if (c.limparProximoVencimento)
        'proximoVencimento': null,
      'updatedAt': agora,
    });
  }

  /// Grava a alteração do valor de parcelas pendentes (KAN-32) em um
  /// único batch: as parcelas, o total da venda e o valor em aberto do
  /// cliente, quando a [diferencaTotal] não é zero.
  ///
  /// Nada é regravado por inteiro. A parcela recebe o valor novo e o
  /// registro entra no histórico com arrayUnion; total da venda e valor
  /// em aberto usam FieldValue.increment. Assim, alterações simultâneas
  /// feitas offline não se sobrescrevem (ADR 001). Os vencimentos não
  /// mudam, então `proximoVencimento` do cliente continua válido.
  Future<void> alterarValoresParcelas({
    required String vendaId,
    required String clienteId,
    required List<ParcelaAlterada> alteracoes,
    required double diferencaTotal,
  }) async {
    final lote = _db.batch();
    final agora = DateTime.now().toIso8601String();

    for (final a in alteracoes) {
      lote.update(_parcelas(vendaId).doc(a.parcelaId), {
        'valor': a.alteracao.valorNovo,
        'alteracoes': FieldValue.arrayUnion([a.alteracao.toMap()]),
        'updatedAt': agora,
      });
    }

    if (diferencaTotal != 0) {
      lote.update(_vendas.doc(vendaId), {
        'valorTotal': FieldValue.increment(diferencaTotal),
        'updatedAt': agora,
      });
      _atualizarCliente(
        lote,
        AtualizacaoClienteVenda(
          clienteId: clienteId,
          acrescimoEmAberto: diferencaTotal,
        ),
      );
    }

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

  /// Grava a observação pós-venda (RF26, KAN-29). Texto vazio limpa o
  /// campo.
  Future<void> salvarObservacao(String vendaId, String observacao) {
    final texto = observacao.trim();
    return _vendas.doc(vendaId).update({
      'observacao': texto.isEmpty ? null : texto,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Grava um pagamento de parcela (KAN-33) em um único batch: o
  /// pagamento entra na parcela e o cliente tem o valor em aberto e o
  /// próximo vencimento atualizados.
  ///
  /// Só os campos que mudam são escritos. O pagamento entra com
  /// arrayUnion e o valor em aberto com FieldValue.increment, então dois
  /// recebimentos offline não se sobrescrevem (ADR 001). Se [quitada], a
  /// parcela também vira paga.
  Future<void> registrarPagamentoParcela({
    required String vendaId,
    required String parcelaId,
    required PagamentoModel pagamento,
    required bool quitada,
    required AtualizacaoClienteVenda cliente,
  }) async {
    final lote = _db.batch();
    lote.update(_parcelas(vendaId).doc(parcelaId), {
      'pagamentos': FieldValue.arrayUnion([pagamento.toMap()]),
      if (quitada) ...{
        'pago': true,
        'dataPagamento': pagamento.data.toIso8601String(),
      },
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _atualizarCliente(lote, cliente);
    await lote.commit();
  }

  /// Parcelas de todas as vendas parceladas do cliente, para recalcular
  /// o próximo vencimento. Lê do servidor e, sem conexão (ou se demorar),
  /// do cache local, que as telas de venda já mantêm atualizado.
  Future<List<ParcelaModel>> parcelasDoCliente(String clienteId) async {
    Future<List<ParcelaModel>> ler(Source fonte) async {
      final vendas = await _vendas
          .where('deleted', isEqualTo: false)
          .where('clienteId', isEqualTo: clienteId)
          .orderBy('data', descending: true)
          .get(GetOptions(source: fonte));
      final ids = [
        for (final d in vendas.docs)
          if (VendaModel.fromMap(d.data()).ehPromissoria) d.id,
      ];
      final listas = await Future.wait([
        for (final id in ids)
          _parcelas(id)
              .where('deleted', isEqualTo: false)
              .orderBy('numero')
              .get(GetOptions(source: fonte)),
      ]);
      return [
        for (final s in listas)
          for (final d in s.docs) ParcelaModel.fromMap(d.data()),
      ];
    }

    try {
      return await ler(Source.serverAndCache)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return ler(Source.cache);
    }
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
