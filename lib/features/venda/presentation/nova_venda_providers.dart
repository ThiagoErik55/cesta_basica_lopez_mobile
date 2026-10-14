import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../produto/data/produto_model.dart';
import '../../produto/data/produto_repository.dart';
import '../domain/carrinho.dart';

/// Produtos disponíveis para venda (KAN-25). Vem do cache do Firestore,
/// então funciona offline com o que já foi carregado.
final produtosVendaProvider = StreamProvider.autoDispose<List<ProdutoModel>>(
  (ref) => ref.watch(produtoRepositoryProvider).observarTodos(),
);

/// Estado da venda em montagem. Nada é gravado ainda.
class NovaVendaState {
  const NovaVendaState({this.itens = const {}});

  /// Itens por id do produto, na ordem em que foram adicionados.
  final Map<String, ItemCarrinho> itens;

  double get total => totalCarrinho(itens.values);

  int get unidades => unidadesCarrinho(itens.values);

  int quantidadeDe(String produtoId) => itens[produtoId]?.quantidade ?? 0;

  NovaVendaState copyWith({Map<String, ItemCarrinho>? itens}) =>
      NovaVendaState(itens: itens ?? this.itens);
}

final novaVendaProvider =
    NotifierProvider.autoDispose<NovaVendaNotifier, NovaVendaState>(
      NovaVendaNotifier.new,
    );

/// Monta o carrinho da venda (KAN-25).
class NovaVendaNotifier extends Notifier<NovaVendaState> {
  @override
  NovaVendaState build() => const NovaVendaState();

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
