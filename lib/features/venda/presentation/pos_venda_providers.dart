import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import '../domain/atualizacao_cliente.dart';
import '../domain/registro_pagamento.dart';
import '../domain/troca.dart';

/// Venda por id, em tempo real (tela de detalhes da venda).
final vendaPorIdProvider = StreamProvider.autoDispose
    .family<VendaModel?, String>(
      (ref, id) => ref.watch(vendaRepositoryProvider).observarPorId(id),
    );

/// Tempo de espera pela primeira leitura das parcelas antes de cair no
/// cache local.
const esperaParcelasAntesDoCache = Duration(seconds: 8);

/// Repassa [origem] e, se ela não emitir nada em [espera], emite o que
/// [cache] devolver (sem perder as emissões que chegarem depois). Cache
/// vazio vira [TimeoutException], para a tela mostrar erro em vez de uma
/// lista vazia enganosa. Erros da [origem] são repassados.
Stream<List<T>> comFallbackDeCache<T>(
  Stream<List<T>> origem,
  Future<List<T>> Function() cache, {
  Duration espera = esperaParcelasAntesDoCache,
}) {
  late final StreamController<List<T>> controlador;
  StreamSubscription<List<T>>? assinatura;
  Timer? relogio;
  var recebeu = false;

  controlador = StreamController<List<T>>(
    onListen: () {
      assinatura = origem.listen(
        (dados) {
          recebeu = true;
          relogio?.cancel();
          controlador.add(dados);
        },
        onError: (Object e, StackTrace s) {
          recebeu = true;
          relogio?.cancel();
          controlador.addError(e, s);
        },
        onDone: () {
          relogio?.cancel();
          controlador.close();
        },
      );
      relogio = Timer(espera, () async {
        if (recebeu || controlador.isClosed) return;
        try {
          final doCache = await cache();
          if (recebeu || controlador.isClosed) return;
          if (doCache.isEmpty) {
            controlador.addError(
              TimeoutException('Sem resposta do servidor nem dados em cache.'),
            );
          } else {
            controlador.add(doCache);
          }
        } catch (e, s) {
          if (!recebeu && !controlador.isClosed) controlador.addError(e, s);
        }
      });
    },
    onCancel: () {
      relogio?.cancel();
      return assinatura?.cancel();
    },
  );
  return controlador.stream;
}

/// Parcelas de uma venda parcelada.
///
/// Sem retentativa automática: o Riverpod 3 refaz providers que falham e,
/// durante as tentativas, mantém o estado como "carregando", o que
/// escondia o erro atrás de um spinner sem fim.
final parcelasDaVendaProvider = StreamProvider.autoDispose
    .family<List<ParcelaModel>, String>((ref, vendaId) {
      final repositorio = ref.watch(vendaRepositoryProvider);
      return comFallbackDeCache(
        repositorio.observarParcelas(vendaId),
        () => repositorio.parcelasEmCache(vendaId),
      );
    }, retry: (_, _) => null);

/// Todas as vendas parceladas (KAN-34), de qualquer cliente.
final vendasParceladasProvider = StreamProvider.autoDispose<List<VendaModel>>(
  (ref) => ref.watch(vendaRepositoryProvider).observarParceladas(),
);

/// Vendas de um cliente, da mais recente para a mais antiga.
final vendasDoClienteProvider = StreamProvider.autoDispose
    .family<List<VendaModel>, String>(
      (ref, clienteId) =>
          ref.watch(vendaRepositoryProvider).observarPorCliente(clienteId),
    );

/// Resultado de [PosVendaNotifier.registrarPagamentoDaParcela].
class PagamentoRegistrado {
  const PagamentoRegistrado({
    required this.pagamentoId,
    required this.sincronizado,
  });

  /// Id do pagamento criado, para abrir o comprovante (KAN-36).
  final String pagamentoId;

  /// `false` quando a gravação ficou na fila offline do Firestore.
  final bool sincronizado;
}

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

  /// Registra um pagamento (total ou parcial) em uma parcela pendente
  /// (KAN-33). Recusas das regras do domínio viram [ArgumentError] com a
  /// mensagem. Devolve o id do pagamento, para o comprovante (KAN-36).
  ///
  /// O próximo vencimento do cliente é o menor entre as parcelas
  /// pendentes de **todas** as vendas dele, e não só desta.
  Future<PagamentoRegistrado> registrarPagamentoDaParcela({
    required VendaModel venda,
    required List<ParcelaModel> parcelas,
    required String parcelaId,
    required double valor,
    required FormaPagamento forma,
    required DateTime data,
    String? observacao,
  }) async {
    final resultado = registrarPagamentoParcela(
      parcelasDaVenda: parcelas,
      parcelaId: parcelaId,
      valor: valor,
      forma: forma,
      data: data,
      observacao: observacao,
    );
    if (!resultado.ok) throw ArgumentError(resultado.erro);

    final repositorio = ref.read(vendaRepositoryProvider);
    final doCliente = await repositorio.parcelasDoCliente(venda.clienteId);
    final depois = [
      ...doCliente.where((p) => p.vendaId != venda.id),
      for (final p in parcelas)
        p.id == parcelaId ? resultado.parcelaAtualizada! : p,
    ];
    final proximo = proximoVencimentoPendente(depois);

    final sincronizado = await _executar(
      repositorio.registrarPagamentoParcela(
        vendaId: venda.id,
        parcelaId: parcelaId,
        pagamento: resultado.pagamento!,
        quitada: resultado.parcelaQuitada,
        cliente: AtualizacaoClienteVenda(
          clienteId: venda.clienteId,
          acrescimoEmAberto: -resultado.pagamento!.valor,
          proximoVencimento: proximo,
          limparProximoVencimento: proximo == null,
        ),
      ),
    );
    return PagamentoRegistrado(
      pagamentoId: resultado.pagamento!.id,
      sincronizado: sincronizado,
    );
  }

  /// Grava a observação pós-venda (RF26). Texto vazio apaga.
  Future<bool> salvarObservacao(String vendaId, String texto) => _executar(
    ref.read(vendaRepositoryProvider).salvarObservacao(vendaId, texto),
  );

  /// Grava a assinatura do cliente na venda (RF19, KAN-38), sobrescrevendo
  /// a anterior. O conteúdo não é logado (LGPD).
  Future<bool> salvarAssinatura(String vendaId, Uint8List imagem) => _executar(
    ref
        .read(vendaRepositoryProvider)
        .salvarAssinatura(
          vendaId: vendaId,
          assinaturaBase64: base64Encode(imagem),
          assinadaEm: DateTime.now(),
        ),
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
