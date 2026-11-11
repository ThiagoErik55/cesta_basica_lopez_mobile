import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/stream_com_cache.dart';
import '../../produto/data/produto_model.dart';
import '../../produto/data/produto_repository.dart';
import '../data/estoque_repository.dart';
import '../data/movimento_estoque_model.dart';
import '../domain/controle_estoque.dart';

/// Filtros da tela de estoque. `null` em situação e categoria = todos.
class FiltroEstoque {
  const FiltroEstoque({this.termo = '', this.situacao, this.categoria});

  final String termo;
  final SituacaoEstoque? situacao;
  final String? categoria;
}

final filtroEstoqueProvider =
    NotifierProvider.autoDispose<FiltroEstoqueNotifier, FiltroEstoque>(
      FiltroEstoqueNotifier.new,
    );

class FiltroEstoqueNotifier extends Notifier<FiltroEstoque> {
  @override
  FiltroEstoque build() => const FiltroEstoque();

  void buscar(String termo) => state = FiltroEstoque(
    termo: termo,
    situacao: state.situacao,
    categoria: state.categoria,
  );

  void filtrarPorSituacao(SituacaoEstoque? situacao) => state = FiltroEstoque(
    termo: state.termo,
    situacao: situacao,
    categoria: state.categoria,
  );

  void filtrarPorCategoria(String? categoria) => state = FiltroEstoque(
    termo: state.termo,
    situacao: state.situacao,
    categoria: categoria,
  );
}

/// Produtos ativos em tempo real, com os valores derivados do estoque.
///
/// Sem retentativa automática: o Riverpod 3 refaz providers que falham e
/// mantém o estado "carregando" durante as tentativas, o que escondia o
/// erro atrás de um spinner. Se o servidor não responde a tempo, cai no
/// cache local.
final itensEstoqueProvider = StreamProvider.autoDispose<List<ItemEstoque>>((
  ref,
) {
  final repositorio = ref.watch(produtoRepositoryProvider);
  final produtos = comFallbackDeCache<ProdutoModel>(
    repositorio.observarAtivos(),
    repositorio.ativosEmCache,
  );
  return produtos.map(montarItensEstoque);
}, retry: (_, _) => null);

/// Movimentações do produto (mais recente primeiro). A consulta filtra só
/// por igualdade (`deleted` e `produtoId`) e a ordem é feita em memória,
/// então não exige índice composto.
final movimentosDoProdutoProvider = StreamProvider.autoDispose
    .family<List<MovimentoEstoqueModel>, String>((ref, produtoId) {
      final repositorio = ref.watch(estoqueRepositoryProvider);
      final movimentos = comFallbackDeCache<MovimentoEstoqueModel>(
        repositorio.observarPorProduto(produtoId),
        () => repositorio.movimentosEmCache(produtoId),
      );
      return movimentos.map(ordenarMovimentos);
    }, retry: (_, _) => null);
