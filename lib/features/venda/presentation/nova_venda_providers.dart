import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Estado da venda em montagem. Nada é gravado ainda.
class NovaVendaState {
  const NovaVendaState({this.cliente, this.itens = const {}});

  final ClienteModel? cliente;

  /// Itens por id do produto, na ordem em que foram adicionados.
  final Map<String, ItemCarrinho> itens;

  double get total => totalCarrinho(itens.values);

  int get unidades => unidadesCarrinho(itens.values);

  int quantidadeDe(String produtoId) => itens[produtoId]?.quantidade ?? 0;

  PendenciaCliente? get pendencia {
    final c = cliente;
    if (c == null) return null;
    return avaliarPendencia(c);
  }

  NovaVendaState copyWith({
    ClienteModel? cliente,
    Map<String, ItemCarrinho>? itens,
  }) => NovaVendaState(
    cliente: cliente ?? this.cliente,
    itens: itens ?? this.itens,
  );
}

final novaVendaProvider =
    NotifierProvider.autoDispose<NovaVendaNotifier, NovaVendaState>(
      NovaVendaNotifier.new,
    );

/// Monta a venda: cliente (KAN-24) e carrinho (KAN-25).
class NovaVendaNotifier extends Notifier<NovaVendaState> {
  @override
  NovaVendaState build() => const NovaVendaState();

  // ---------------- Cliente (KAN-24) ----------------

  void selecionarCliente(ClienteModel cliente) =>
      state = state.copyWith(cliente: cliente);

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
}
