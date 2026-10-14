import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../../produto/data/produto_model.dart';
import 'nova_venda_providers.dart';
import 'seletor_quantidade.dart';

/// Lista de produtos com busca, categorias e quantidade (KAN-25).
class SecaoProdutosVenda extends ConsumerStatefulWidget {
  const SecaoProdutosVenda({super.key});

  @override
  ConsumerState<SecaoProdutosVenda> createState() => _SecaoProdutosVendaState();
}

class _SecaoProdutosVendaState extends ConsumerState<SecaoProdutosVenda> {
  String _termo = '';
  String? _categoria;

  List<ProdutoModel> _filtrar(List<ProdutoModel> todos) {
    final termo = _termo.trim().toLowerCase();
    return todos.where((p) {
      if (_categoria != null && p.categoria != _categoria) return false;
      if (termo.isEmpty) return true;
      return p.nome.toLowerCase().contains(termo) ||
          p.marca.toLowerCase().contains(termo) ||
          p.codigo.toLowerCase().contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final produtos = ref.watch(produtosVendaProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(titulo: 'Produtos'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          onChanged: (texto) => setState(() => _termo = texto),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar produto, marca ou código',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        produtos.when(
          data: (todos) {
            final categorias =
                todos
                    .map((p) => p.categoria)
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final lista = _filtrar(todos);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (categorias.length > 1) ...[
                  FilterChipBar<String>(
                    opcoes: [
                      const OpcaoFiltro('Todos', null),
                      for (final c in categorias) OpcaoFiltro(c, c),
                    ],
                    selecionado: _categoria,
                    onSelecionar: (c) => setState(() => _categoria = c),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (lista.isEmpty)
                  EmptyState(
                    icone: Icons.inventory_2_outlined,
                    titulo: todos.isEmpty
                        ? 'Nenhum produto cadastrado'
                        : 'Nenhum produto encontrado',
                    descricao: todos.isEmpty
                        ? 'Cadastre produtos na aba Estoque.'
                        : 'Tente outro nome ou categoria.',
                  )
                else
                  for (final produto in lista) ...[
                    _ProdutoVendaCard(produto: produto),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) {
            debugPrint('Erro ao carregar produtos na venda: $error');
            return const EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar produtos',
              descricao: 'Verifique a conexão e tente novamente.',
            );
          },
        ),
      ],
    );
  }
}

class _ProdutoVendaCard extends ConsumerWidget {
  const _ProdutoVendaCard({required this.produto});

  final ProdutoModel produto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantidade = ref.watch(
      novaVendaProvider.select((v) => v.quantidadeDe(produto.id)),
    );
    final notifier = ref.read(novaVendaProvider.notifier);
    final semEstoque = quantidade > produto.estoqueAtual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nome, style: AppTextStyles.cardTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatarMoeda(produto.preco),
                    style: AppTextStyles.money.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Estoque: ${produto.estoqueAtual}',
                    style: AppTextStyles.caption.copyWith(
                      color: produto.estoqueBaixo
                          ? AppColors.statusAtencao
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (semEstoque)
                    Text(
                      'Acima do estoque registrado',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.statusInadimplente,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SeletorQuantidade(
              quantidade: quantidade,
              onAdicionar: () => notifier.adicionar(produto),
              onRemover: () => notifier.remover(produto),
            ),
          ],
        ),
      ),
    );
  }
}
