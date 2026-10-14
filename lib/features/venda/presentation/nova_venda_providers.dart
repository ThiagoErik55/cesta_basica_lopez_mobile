import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../cliente/data/cliente_model.dart';
import '../../cliente/data/cliente_repository.dart';
import '../../produto/data/produto_model.dart';
import '../../produto/data/produto_repository.dart';
import '../domain/carrinho.dart';
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

/// Estado da venda em montagem. Nada é gravado ainda.
class NovaVendaState {
  const NovaVendaState({
    this.cliente,
    this.itens = const {},
    this.pagamento,
    this.numeroParcelas = 2,
    required this.primeiroVencimento,
  });

  final ClienteModel? cliente;

  /// Itens por id do produto, na ordem em que foram adicionados.
  final Map<String, ItemCarrinho> itens;
  final OpcaoPagamento? pagamento;
  final int numeroParcelas;
  final DateTime primeiroVencimento;

  double get total => totalCarrinho(itens.values);

  int get unidades => unidadesCarrinho(itens.values);

  bool get parcelado => pagamento is PagamentoParcelado;

  int quantidadeDe(String produtoId) => itens[produtoId]?.quantidade ?? 0;

  PendenciaCliente? get pendencia {
    final c = cliente;
    if (c == null) return null;
    return avaliarPendencia(c, valorVendaParcelada: parcelado ? total : 0);
  }

  NovaVendaState copyWith({
    ClienteModel? cliente,
    Map<String, ItemCarrinho>? itens,
    OpcaoPagamento? pagamento,
    bool limparPagamento = false,
    int? numeroParcelas,
    DateTime? primeiroVencimento,
  }) => NovaVendaState(
    cliente: cliente ?? this.cliente,
    itens: itens ?? this.itens,
    pagamento: limparPagamento ? null : (pagamento ?? this.pagamento),
    numeroParcelas: numeroParcelas ?? this.numeroParcelas,
    primeiroVencimento: primeiroVencimento ?? this.primeiroVencimento,
  );
}

final novaVendaProvider =
    NotifierProvider.autoDispose<NovaVendaNotifier, NovaVendaState>(
      NovaVendaNotifier.new,
    );

/// Monta a venda: cliente (KAN-24), carrinho (KAN-25) e pagamento
/// (KAN-26).
class NovaVendaNotifier extends Notifier<NovaVendaState> {
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
    );
  }

  // ---------------- Cliente (KAN-24) ----------------

  void selecionarCliente(ClienteModel cliente) {
    var novo = state.copyWith(cliente: cliente);
    // Cliente bloqueado não pode ficar com parcelado selecionado.
    if (novo.parcelado && !(novo.pendencia?.permiteParcelado ?? true)) {
      novo = novo.copyWith(limparPagamento: true);
    }
    state = novo;
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
}
