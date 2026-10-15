import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../data/produto_model.dart';
import '../data/produto_repository.dart';
import '../domain/dados_cadastrais_produto.dart';

/// Filtros da listagem de produtos: termo de busca (já "debounced" pela
/// tela) e categoria (`null` = todas).
class FiltroProdutos {
  const FiltroProdutos({this.termo = '', this.categoria});

  final String termo;
  final String? categoria;
}

final filtroProdutosProvider =
    NotifierProvider<FiltroProdutosNotifier, FiltroProdutos>(
      FiltroProdutosNotifier.new,
    );

class FiltroProdutosNotifier extends Notifier<FiltroProdutos> {
  @override
  FiltroProdutos build() => const FiltroProdutos();

  void buscar(String termo) =>
      state = FiltroProdutos(termo: termo.trim(), categoria: state.categoria);

  void filtrarPorCategoria(String? categoria) =>
      state = FiltroProdutos(termo: state.termo, categoria: categoria);
}

/// Resultado da busca por nome (RF02). Termo vazio lista todos; caso
/// contrário, busca por prefixo do nome via repositório.
///
/// Observa só o termo: trocar a categoria não reabre o listener do
/// Firestore — a categoria é aplicada em memória em [produtosProvider].
final _produtosBuscadosProvider =
    StreamProvider.autoDispose<List<ProdutoModel>>((ref) {
      final termo = ref.watch(filtroProdutosProvider.select((f) => f.termo));
      final repositorio = ref.watch(produtoRepositoryProvider);
      return termo.isEmpty
          ? repositorio.observarTodos()
          : repositorio.buscarPorNome(termo);
    });

/// Lista exibida na tela de produtos: o resultado da busca por nome,
/// filtrado pela categoria selecionada (KAN-23).
final produtosProvider = Provider.autoDispose<AsyncValue<List<ProdutoModel>>>((
  ref,
) {
  final categoria = ref.watch(
    filtroProdutosProvider.select((f) => f.categoria),
  );
  final buscados = ref.watch(_produtosBuscadosProvider);
  if (categoria == null) return buscados;
  return buscados.whenData(
    (lista) => lista.where((p) => p.categoria == categoria).toList(),
  );
});

/// Produto por id, para a tela de edição. `null` quando não existe ou
/// foi removido. É invalidado por [SalvarProdutoNotifier] após uma
/// edição, para a tela recarregar os dados.
final produtoPorIdProvider = FutureProvider.autoDispose
    .family<ProdutoModel?, String>((ref, id) {
      return ref.watch(produtoRepositoryProvider).buscarPorId(id);
    });

/// Cadastro e edição de produto (KAN-23). O estado expõe o carregamento
/// e o erro do último salvamento para a tela; a montagem do
/// [ProdutoModel] fica aqui, fora da UI.
final salvarProdutoProvider =
    AsyncNotifierProvider.autoDispose<SalvarProdutoNotifier, void>(
      SalvarProdutoNotifier.new,
    );

class SalvarProdutoNotifier extends AsyncNotifier<void> {
  /// Quanto esperar a confirmação do servidor antes de considerar a
  /// escrita enfileirada offline (mesmo motivo de SalvarClienteNotifier).
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Cadastra um produto novo. Estoque atual começa em 0 (padrão do
  /// model): entradas de estoque são lançadas como movimento, não aqui
  /// (ADR 001).
  Future<bool> cadastrar(DadosCadastraisProduto dados) {
    final id = gerarId();
    return _gravar(
      ProdutoModel(
        id: id,
        // Código interno provisório derivado do UUID, mesmo raciocínio
        // do código do cliente: um sequencial central colidiria entre
        // vendedores cadastrando offline (ADR 001).
        codigo: 'P-${id.substring(0, 8).toUpperCase()}',
        nome: dados.nome,
        marca: dados.marca,
        categoria: dados.categoria,
        preco: dados.preco,
        custoAtual: dados.custoAtual,
        estoqueMinimo: dados.estoqueMinimo,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Atualiza os dados cadastrais de [original], mantendo id, código e
  /// estoqueAtual (cache de movimentos, não editado aqui). Mesmo retorno
  /// de [cadastrar].
  Future<bool> atualizar(
    ProdutoModel original,
    DadosCadastraisProduto dados,
  ) async {
    final sincronizado = await _gravar(
      ProdutoModel(
        id: original.id,
        codigo: original.codigo,
        nome: dados.nome,
        marca: dados.marca,
        categoria: dados.categoria,
        preco: dados.preco,
        custoAtual: dados.custoAtual,
        estoqueAtual: original.estoqueAtual,
        estoqueMinimo: dados.estoqueMinimo,
        updatedAt: DateTime.now(),
        deleted: original.deleted,
      ),
    );
    ref.invalidate(produtoPorIdProvider(original.id));
    return sincronizado;
  }

  Future<bool> _gravar(ProdutoModel produto) async {
    state = const AsyncLoading();
    try {
      final escrita = ref.read(produtoRepositoryProvider).salvar(produto);
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
