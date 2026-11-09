import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/id_generator.dart';
import '../../estoque/data/movimento_estoque_model.dart';
import '../../produto/data/produto_model.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../data/venda_repository.dart';
import '../domain/alteracao_parcela.dart';
import '../domain/troca.dart';

/// Venda por id, em tempo real (tela de detalhes da venda).
final vendaPorIdProvider = StreamProvider.autoDispose
    .family<VendaModel?, String>(
      (ref, id) => ref.watch(vendaRepositoryProvider).observarPorId(id),
    );

/// Parcelas de uma venda parcelada.
final parcelasDaVendaProvider = StreamProvider.autoDispose
    .family<List<ParcelaModel>, String>(
      (ref, vendaId) =>
          ref.watch(vendaRepositoryProvider).observarParcelas(vendaId),
    );

/// Vendas de um cliente, da mais recente para a mais antiga.
final vendasDoClienteProvider = StreamProvider.autoDispose
    .family<List<VendaModel>, String>(
      (ref, clienteId) =>
          ref.watch(vendaRepositoryProvider).observarPorCliente(clienteId),
    );

final posVendaProvider =
    AsyncNotifierProvider.autoDispose<PosVendaNotifier, void>(
      PosVendaNotifier.new,
    );

/// Ações sobre uma venda já registrada: troca (KAN-28) e observação
/// (KAN-29). Os métodos retornam `true` se o servidor confirmou e
/// `false` se a escrita ficou na fila offline.
class PosVendaNotifier extends AsyncNotifier<void> {
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Troca [quantidade] unidades de [original] por [novo] (RF25).
  ///
  /// Estoque: o produto original volta (entrada) e o novo sai (troca).
  /// A diferença de valor é acertada na hora com o cliente e fica
  /// registrada na troca e na observação — as parcelas não são
  /// alteradas.
  Future<bool> registrarTroca({
    required VendaModel venda,
    required ItemVenda original,
    required ProdutoModel novo,
    required int quantidade,
  }) {
    final disponivel = quantidadeTrocavel(venda, original);
    if (quantidade <= 0 || quantidade > disponivel) {
      throw ArgumentError('Quantidade inválida para troca.');
    }
    if (novo.id == original.produtoId) {
      throw ArgumentError('Escolha um produto diferente do original.');
    }

    final vendedorUid = ref.read(usuarioLogadoProvider).value?.uid;
    if (vendedorUid == null) throw StateError('Sessão expirada.');

    final agora = DateTime.now();
    final diferenca = diferencaTroca(
      original: original,
      novo: novo,
      quantidade: quantidade,
    );

    final troca = TrocaItem(
      id: gerarId(),
      itemOriginalId: original.id,
      produtoNovoId: novo.id,
      produtoNovoNome: novo.nome,
      quantidade: quantidade,
      diferencaValor: diferenca,
      data: agora,
    );

    final movimentos = [
      MovimentoEstoqueModel(
        id: gerarId(),
        produtoId: original.produtoId,
        vendaId: venda.id,
        tipo: TipoMovimento.entrada,
        quantidade: quantidade,
        data: agora,
        vendedorUid: vendedorUid,
        updatedAt: agora,
      ),
      MovimentoEstoqueModel(
        id: gerarId(),
        produtoId: novo.id,
        vendaId: venda.id,
        tipo: TipoMovimento.troca,
        quantidade: quantidade,
        data: agora,
        vendedorUid: vendedorUid,
        updatedAt: agora,
      ),
    ];

    final observacao = acrescentarObservacao(
      venda.observacao,
      descricaoTroca(
        data: agora,
        original: original,
        novo: novo,
        quantidade: quantidade,
        diferenca: diferenca,
      ),
    );

    return _executar(
      ref
          .read(vendaRepositoryProvider)
          .registrarTroca(
            vendaId: venda.id,
            troca: troca,
            observacao: observacao,
            movimentos: movimentos,
          ),
    );
  }

  /// Altera o valor de uma parcela pendente (KAN-32). O cálculo é refeito
  /// aqui com os dados atuais; se a alteração for recusada pelas regras
  /// do domínio, lança [ArgumentError] com a mensagem.
  Future<bool> registrarAlteracaoParcela({
    required VendaModel venda,
    required List<ParcelaModel> parcelas,
    required String parcelaId,
    required double novoValor,
    required ModoCompensacao modo,
    String? motivo,
  }) {
    final resultado = alterarValorParcela(
      parcelas: parcelas,
      parcelaId: parcelaId,
      novoValor: novoValor,
      modo: modo,
      valorTotalVenda: venda.valorTotal,
      motivo: motivo,
    );
    if (!resultado.ok) throw ArgumentError(resultado.erro);

    return _executar(
      ref
          .read(vendaRepositoryProvider)
          .alterarValoresParcelas(
            vendaId: venda.id,
            clienteId: venda.clienteId,
            alteracoes: resultado.alteradas,
            diferencaTotal: resultado.diferencaTotal,
          ),
    );
  }

  /// Grava a observação pós-venda (RF26). Texto vazio apaga.
  Future<bool> salvarObservacao(String vendaId, String texto) => _executar(
    ref.read(vendaRepositoryProvider).salvarObservacao(vendaId, texto),
  );

  Future<bool> _executar(Future<void> escrita) async {
    state = const AsyncLoading();
    try {
      final sincronizado = await escrita
          .then((_) => true)
          .timeout(_esperaConfirmacao, onTimeout: () => false);
      state = const AsyncData(null);
      return sincronizado;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
