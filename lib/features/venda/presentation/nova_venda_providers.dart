import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/regra_bloqueio_provider.dart';
import '../../../core/providers/regra_estoque_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../cliente/data/cliente_model.dart';
import '../../cliente/data/cliente_repository.dart';
import '../../cliente/domain/regra_bloqueio.dart';
import '../../estoque/data/movimento_estoque_model.dart';
import '../../estoque/domain/regra_estoque.dart';
import '../../produto/data/produto_model.dart';
import '../../produto/data/produto_repository.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../data/venda_repository.dart';
import '../domain/atualizacao_cliente.dart';
import '../domain/calculo_parcelas.dart';
import '../domain/carrinho.dart';
import '../domain/estoque_venda.dart';
import '../domain/pendencia_cliente.dart';

/// Produtos disponíveis para venda (KAN-25). Vem do cache do Firestore,
/// então funciona offline com o que já foi carregado.
final produtosVendaProvider = StreamProvider.autoDispose<List<ProdutoModel>>(
  (ref) => ref.watch(produtoRepositoryProvider).observarTodos(),
);

/// Todos os clientes, para a busca da nova venda (KAN-24). A filtragem
/// por nome ou CPF é feita em memória: permite buscar por CPF e por
/// qualquer parte do nome, o que a consulta por prefixo não faz.
final clientesVendaProvider = StreamProvider.autoDispose<List<ClienteModel>>(
  (ref) => ref.watch(clienteRepositoryProvider).observarTodos(),
);

/// Pagamento escolhido: à vista com uma forma, ou parcelado.
sealed class OpcaoPagamento {
  const OpcaoPagamento();
}

class PagamentoAVista extends OpcaoPagamento {
  const PagamentoAVista(this.forma);
  final FormaPagamento forma;

  @override
  bool operator ==(Object other) =>
      other is PagamentoAVista && other.forma == forma;

  @override
  int get hashCode => forma.hashCode;
}

class PagamentoParcelado extends OpcaoPagamento {
  const PagamentoParcelado();

  @override
  bool operator ==(Object other) => other is PagamentoParcelado;

  @override
  int get hashCode => 0;
}

/// Estado da venda em montagem. Nada é gravado até [NovaVendaNotifier.finalizar].
class NovaVendaState {
  const NovaVendaState({
    this.cliente,
    this.itens = const {},
    this.pagamento,
    this.numeroParcelas = 2,
    required this.primeiroVencimento,
    this.regra = regraBloqueioPadrao,
    this.regraEstoque = regraEstoquePadrao,
    this.parcelasPendentes,
  });

  final ClienteModel? cliente;

  /// Itens por id do produto, na ordem em que foram adicionados.
  final Map<String, ItemCarrinho> itens;
  final OpcaoPagamento? pagamento;
  final int numeroParcelas;
  final DateTime primeiroVencimento;

  /// Regra de bloqueio em vigor (KAN-35).
  final RegraBloqueio regra;

  /// Política de estoque insuficiente em vigor (KAN-43).
  final RegraEstoque regraEstoque;

  /// Parcelas pendentes de todas as vendas do cliente selecionado, para
  /// avaliar o bloqueio por atraso. `null` até carregar; nesse meio
  /// tempo a avaliação usa o resumo do cliente.
  final List<ParcelaModel>? parcelasPendentes;

  double get total => totalCarrinho(itens.values);

  int get unidades => unidadesCarrinho(itens.values);

  bool get parcelado => pagamento is PagamentoParcelado;

  int quantidadeDe(String produtoId) => itens[produtoId]?.quantidade ?? 0;

  PendenciaCliente? get pendencia {
    final c = cliente;
    if (c == null) return null;
    return avaliarPendencia(
      c,
      regra: regra,
      parcelasPendentes: parcelasPendentes,
      valorVendaParcelada: parcelado ? total : 0,
    );
  }

  /// Aviso único do resumo quando há itens acima do estoque e a regra
  /// permite a venda; `null` sem itens acima ou com bloqueio ligado.
  String? get avisoEstoque => avisoResumoEstoque(itens.values, regraEstoque);

  /// O que ainda falta para finalizar, ou `null` se está tudo certo.
  String? get impedimento {
    if (cliente == null) return 'Selecione o cliente.';
    final pendencia = this.pendencia;
    if (pendencia != null &&
        !pendencia.permiteAVista &&
        !pendencia.permiteParcelado) {
      return pendencia.mensagens.first;
    }
    if (itens.isEmpty) return 'Adicione pelo menos um produto.';
    // Só com a regra de bloqueio ligada; desligada, a venda segue e o
    // estoque pode ficar negativo.
    final semEstoque = impedimentosDeEstoque(itens.values, regraEstoque);
    if (semEstoque.isNotEmpty) return semEstoque.join('\n');
    if (pagamento == null) return 'Escolha a forma de pagamento.';
    if (pendencia != null) {
      if (parcelado && !pendencia.permiteParcelado) {
        return pendencia.mensagens.first;
      }
      if (!parcelado && !pendencia.permiteAVista) {
        return pendencia.mensagens.first;
      }
    }
    if (parcelado) {
      return validarParcelamento(
        quantidade: numeroParcelas,
        primeiroVencimento: primeiroVencimento,
      );
    }
    return null;
  }

  NovaVendaState copyWith({
    ClienteModel? cliente,
    Map<String, ItemCarrinho>? itens,
    OpcaoPagamento? pagamento,
    bool limparPagamento = false,
    int? numeroParcelas,
    DateTime? primeiroVencimento,
    List<ParcelaModel>? parcelasPendentes,
    bool limparParcelasPendentes = false,
  }) => NovaVendaState(
    cliente: cliente ?? this.cliente,
    itens: itens ?? this.itens,
    pagamento: limparPagamento ? null : (pagamento ?? this.pagamento),
    numeroParcelas: numeroParcelas ?? this.numeroParcelas,
    primeiroVencimento: primeiroVencimento ?? this.primeiroVencimento,
    regra: regra,
    regraEstoque: regraEstoque,
    parcelasPendentes: limparParcelasPendentes
        ? null
        : (parcelasPendentes ?? this.parcelasPendentes),
  );
}

/// Resultado de [NovaVendaNotifier.finalizar].
class VendaFinalizada {
  const VendaFinalizada({required this.venda, required this.sincronizado});

  final VendaModel venda;

  /// `false` quando a gravação ficou na fila offline do Firestore.
  final bool sincronizado;
}

final novaVendaProvider =
    NotifierProvider.autoDispose<NovaVendaNotifier, NovaVendaState>(
      NovaVendaNotifier.new,
    );

/// Monta a venda (KAN-24, KAN-25, KAN-26) e grava ao finalizar (KAN-27).
class NovaVendaNotifier extends Notifier<NovaVendaState> {
  /// Mesmo critério do cadastro de cliente: sem sinal, o Future do
  /// Firestore só completa quando a conexão volta, mas os dados já estão
  /// no cache local.
  static const _esperaConfirmacao = Duration(seconds: 3);

  static const prazoPrimeiraParcela = Duration(days: 30);

  @override
  NovaVendaState build() {
    final hoje = DateTime.now();
    return NovaVendaState(
      primeiroVencimento: DateTime(
        hoje.year,
        hoje.month,
        hoje.day,
      ).add(prazoPrimeiraParcela),
      regra: ref.read(regraBloqueioProvider),
      regraEstoque: ref.read(regraEstoqueProvider),
    );
  }

  // ---------------- Cliente (KAN-24) ----------------

  void selecionarCliente(ClienteModel cliente) {
    // As parcelas do cliente anterior não valem para o novo.
    var novo = state.copyWith(cliente: cliente, limparParcelasPendentes: true);
    // Cliente bloqueado não pode ficar com um pagamento que a pendência
    // não permite (manual: nenhum; automático: parcelado).
    final pendencia = novo.pendencia;
    final pagamentoPermitido = novo.parcelado
        ? (pendencia?.permiteParcelado ?? true)
        : (pendencia?.permiteAVista ?? true);
    if (novo.pagamento != null && !pagamentoPermitido) {
      novo = novo.copyWith(limparPagamento: true);
    }
    state = novo;
    _carregarParcelasPendentes(cliente.id);
  }

  /// Busca as parcelas pendentes de todas as vendas do cliente para a
  /// regra de bloqueio por atraso (KAN-35). Lê do servidor ou do cache
  /// local, então funciona offline. Até chegar, vale o resumo do cliente.
  Future<void> _carregarParcelasPendentes(String clienteId) async {
    try {
      final parcelas = await ref
          .read(vendaRepositoryProvider)
          .parcelasDoCliente(clienteId);
      // O vendedor pode ter trocado de cliente enquanto carregava.
      if (!ref.mounted || state.cliente?.id != clienteId) return;
      var novo = state.copyWith(
        parcelasPendentes: [
          for (final p in parcelas)
            if (!p.pago) p,
        ],
      );
      final pendencia = novo.pendencia;
      final pagamentoPermitido = novo.parcelado
          ? (pendencia?.permiteParcelado ?? true)
          : (pendencia?.permiteAVista ?? true);
      if (novo.pagamento != null && !pagamentoPermitido) {
        novo = novo.copyWith(limparPagamento: true);
      }
      state = novo;
    } catch (e) {
      // Sem as parcelas, segue valendo o resumo do cliente.
      debugPrint('Erro ao carregar parcelas do cliente $clienteId: $e');
    }
  }

  // ---------------- Carrinho (KAN-25) ----------------

  void adicionar(ProdutoModel produto) =>
      definirQuantidade(produto, state.quantidadeDe(produto.id) + 1);

  void remover(ProdutoModel produto) =>
      definirQuantidade(produto, state.quantidadeDe(produto.id) - 1);

  /// Quantidade 0 ou negativa tira o produto do carrinho.
  void definirQuantidade(ProdutoModel produto, int quantidade) {
    final itens = Map<String, ItemCarrinho>.of(state.itens);
    if (quantidade <= 0) {
      itens.remove(produto.id);
    } else {
      itens[produto.id] = ItemCarrinho(
        produto: produto,
        quantidade: quantidade,
      );
    }
    state = state.copyWith(itens: itens);
  }

  void limparCarrinho() => state = state.copyWith(itens: {});

  // ---------------- Pagamento (KAN-26) ----------------

  void selecionarPagamento(OpcaoPagamento opcao) =>
      state = state.copyWith(pagamento: opcao);

  void definirNumeroParcelas(int quantidade) =>
      state = state.copyWith(numeroParcelas: quantidade);

  void definirPrimeiroVencimento(DateTime data) =>
      state = state.copyWith(primeiroVencimento: data);

  // ---------------- Finalizar (KAN-27) ----------------

  /// Grava venda, parcelas, baixa de estoque e cliente em lote (modelo
  /// lógico, seção 6). Lança [StateError] se faltar algo — a tela só
  /// chama depois de checar [NovaVendaState.impedimento].
  Future<VendaFinalizada> finalizar() async {
    final s = state;
    final impedimento = s.impedimento;
    if (impedimento != null) throw StateError(impedimento);

    final vendedorUid = ref.read(usuarioLogadoProvider).value?.uid;
    if (vendedorUid == null) throw StateError('Sessão expirada.');

    final cliente = s.cliente!;
    final agora = DateTime.now();
    final vendaId = gerarId();
    final total = s.total;

    final venda = VendaModel(
      id: vendaId,
      clienteId: cliente.id,
      clienteNome: cliente.nome,
      vendedorUid: vendedorUid,
      numeroNota: gerarNumeroNota(agora),
      data: agora,
      itens: [
        for (final item in s.itens.values)
          ItemVenda(
            id: gerarId(),
            produtoId: item.produto.id,
            nome: item.produto.nome,
            quantidade: item.quantidade,
            precoUnitario: item.produto.preco,
            custoUnitario: item.produto.custoAtual,
          ),
      ],
      valorTotal: total,
      formaPagamento: switch (s.pagamento) {
        PagamentoAVista(:final forma) => forma,
        _ => null,
      },
      tipo: s.parcelado ? TipoVenda.parcelado : TipoVenda.aVista,
      updatedAt: agora,
    );

    final parcelas = s.parcelado
        ? gerarParcelas(
            vendaId: vendaId,
            total: total,
            quantidade: s.numeroParcelas,
            primeiroVencimento: s.primeiroVencimento,
            agora: agora,
          )
        : const <ParcelaModel>[];

    // Baixa de estoque (RF23): uma saída por item, com o custo atual do
    // produto (para o lucro real). Bloqueio por estoque só se a
    // RegraEstoque pedir (ver impedimento).
    final movimentos = [
      for (final item in s.itens.values)
        MovimentoEstoqueModel(
          id: gerarId(),
          produtoId: item.produto.id,
          vendaId: vendaId,
          tipo: TipoMovimento.saida,
          quantidade: item.quantidade,
          data: agora,
          custoUnitario: item.produto.custoAtual,
          vendedorUid: vendedorUid,
          updatedAt: agora,
        ),
    ];

    final atualizacaoCliente = atualizacaoClienteDaVenda(
      clienteId: cliente.id,
      agora: agora,
      parcelas: parcelas,
      valorEmAbertoAtual: cliente.valorEmAberto,
      proximoVencimentoAtual: cliente.proximoVencimento,
    );

    final escrita = ref
        .read(vendaRepositoryProvider)
        .registrarVenda(
          venda: venda,
          parcelas: parcelas,
          movimentos: movimentos,
          cliente: atualizacaoCliente,
        );
    final sincronizado = await escrita
        .then((_) => true)
        .timeout(_esperaConfirmacao, onTimeout: () => false);

    return VendaFinalizada(venda: venda, sincronizado: sincronizado);
  }
}

/// Número da nota provisória (RF18) a partir da data e hora da venda,
/// ex. 2610141530 (14/10/26 15:30) seguido dos segundos.
///
/// Um contador sequencial (1, 2, 3...) precisaria de um documento
/// central, que conflitaria com dois vendedores vendendo offline
/// (ADR 001). Com data e hora, a chance de repetir é dois vendedores
/// finalizarem no mesmo segundo.
int gerarNumeroNota(DateTime data) =>
    int.parse(DateFormat('yyMMddHHmmss').format(data));
