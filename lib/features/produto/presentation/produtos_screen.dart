import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/product_card.dart';
import '../../auth/presentation/logout_button.dart';
import 'produto_providers.dart';

/// Aba de listagem e busca de produtos (KAN-23). A busca é por prefixo
/// do nome (limitação do Firestore, ver campo nomeBusca no modelo
/// lógico) e só dispara depois de uma pausa na digitação. O filtro por
/// categoria é aplicado sobre o resultado da busca.
class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerState<ProdutosScreen> {
  static const _debounce = Duration(milliseconds: 300);

  // Começa com o termo que já está no provider, que sobrevive à tela
  // (ex. ao sair e voltar do login).
  late final _busca = TextEditingController(
    text: ref.read(filtroProdutosProvider).termo,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) ref.read(filtroProdutosProvider.notifier).buscar(texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    ref.read(filtroProdutosProvider.notifier).buscar('');
  }

  @override
  Widget build(BuildContext context) {
    final produtos = ref.watch(produtosProvider);
    final filtro = ref.watch(filtroProdutosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            tooltip: 'Controle de estoque',
            icon: const Icon(Icons.warehouse_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.estoque),
          ),
          const LogoutButton(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'novoProduto',
        tooltip: 'Novo produto',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textoContrastante(AppColors.primary),
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.cadastroProduto),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: ValueListenableBuilder(
              valueListenable: _busca,
              builder: (context, valor, _) => TextField(
                controller: _busca,
                onChanged: _aoDigitar,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar pelo nome',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: valor.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close),
                          onPressed: _limparBusca,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: produtos.when(
              // Mantém a lista anterior visível enquanto o novo termo
              // carrega, em vez de piscar um indicador a cada busca.
              skipLoadingOnReload: true,
              data: (lista) {
                final categorias =
                    lista
                        .map((p) => p.categoria)
                        .where((c) => c.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (categorias.length > 1) ...[
                      FilterChipBar<String>(
                        opcoes: [
                          const OpcaoFiltro('Todas', null),
                          for (final c in categorias) OpcaoFiltro(c, c),
                        ],
                        selecionado: filtro.categoria,
                        onSelecionar: ref
                            .read(filtroProdutosProvider.notifier)
                            .filtrarPorCategoria,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Expanded(
                      child: lista.isEmpty
                          ? _vazio(filtro)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                // Espaço para o FAB não cobrir o último card.
                                AppSpacing.xl * 3,
                              ),
                              itemCount: lista.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) => ProductCard(
                                produto: lista[i],
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.editarProduto,
                                  arguments: lista[i],
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                // O erro do Firestore (ex. índice ausente, com o link para
                // criá-lo) só aparece no log — a tela mostra uma mensagem
                // genérica.
                debugPrint('Erro ao carregar produtos: $error');
                return const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao carregar produtos',
                    descricao: 'Verifique a conexão e tente novamente.',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _vazio(FiltroProdutos filtro) {
    final semFiltro = filtro.termo.isEmpty && filtro.categoria == null;
    final descricao = switch ((filtro.termo, filtro.categoria)) {
      ('', final categoria?) => 'Nenhum produto na categoria "$categoria".',
      (final termo, null) => 'Nenhum nome começa com "$termo".',
      (final termo, final categoria?) =>
        'Nenhum produto "$categoria" com nome começando por "$termo".',
    };

    return Center(
      child: SingleChildScrollView(
        child: semFiltro
            ? const EmptyState(
                icone: Icons.inventory_2_outlined,
                titulo: 'Nenhum produto cadastrado',
                descricao: 'Toque em + para cadastrar o primeiro produto.',
              )
            : EmptyState(
                icone: Icons.search_off,
                titulo: 'Nenhum produto encontrado',
                descricao: descricao,
              ),
      ),
    );
  }
}
