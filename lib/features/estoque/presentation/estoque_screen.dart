import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/product_card.dart';
import '../domain/controle_estoque.dart';
import 'detalhe_estoque_sheet.dart';
import 'estoque_providers.dart';
import 'registrar_entrada_sheet.dart';
import 'selo_situacao_estoque.dart';

/// Controle de estoque (KAN-41): consulta do estoque dos produtos, em
/// tempo real e com o cache offline, com resumo, busca e filtros.
///
/// Só consulta. Registrar entrada (KAN-42), baixa na venda (KAN-43) e
/// alerta de estoque baixo (KAN-44) são tarefas à parte.
class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({super.key});

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
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
      if (mounted) ref.read(filtroEstoqueProvider.notifier).buscar(texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    ref.read(filtroEstoqueProvider.notifier).buscar('');
  }

  @override
  Widget build(BuildContext context) {
    final itens = ref.watch(itensEstoqueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'registrarEntrada',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textoContrastante(AppColors.primary),
        onPressed: () => registrarEntradaSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar entrada'),
      ),
      body: itens.when(
        data: _conteudo,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar estoque: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar o estoque',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }

  Widget _conteudo(List<ItemEstoque> todos) {
    if (todos.isEmpty) {
      return const Center(
        child: EmptyState(
          icone: Icons.inventory_2_outlined,
          titulo: 'Nenhum produto cadastrado',
          descricao:
              'Cadastre produtos na aba Produtos para controlar o estoque.',
        ),
      );
    }

    final filtro = ref.watch(filtroEstoqueProvider);
    final notificador = ref.read(filtroEstoqueProvider.notifier);
    final categorias = categoriasDoEstoque(todos);
    final itens = ordenarEstoque(
      filtrarEstoque(
        todos,
        situacao: filtro.situacao,
        categoria: filtro.categoria,
        termo: filtro.termo,
      ),
    );

    return Column(
      children: [
        // O resumo considera todos os produtos, não só os filtrados.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _Resumo(resumo: resumirEstoque(todos)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
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
                hintText: 'Buscar por nome, marca ou código',
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
        FilterChipBar<SituacaoEstoque>(
          opcoes: const [
            OpcaoFiltro('Todos', null),
            OpcaoFiltro('Normal', SituacaoEstoque.normal),
            OpcaoFiltro('Baixo', SituacaoEstoque.baixo),
            OpcaoFiltro('Sem estoque', SituacaoEstoque.semEstoque),
          ],
          selecionado: filtro.situacao,
          onSelecionar: notificador.filtrarPorSituacao,
        ),
        if (categorias.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          FilterChipBar<String>(
            opcoes: [
              const OpcaoFiltro('Todas as categorias', null),
              for (final c in categorias) OpcaoFiltro(c, c),
            ],
            selecionado: filtro.categoria,
            onSelecionar: notificador.filtrarPorCategoria,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: itens.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icone: Icons.search_off,
                      titulo: 'Nenhum produto encontrado',
                      descricao: 'Ajuste a busca ou os filtros.',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    // Espaço para o botão não cobrir o último card.
                    AppSpacing.xl * 3,
                  ),
                  itemCount: itens.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CardEstoque(item: itens[i]),
                ),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.resumo});

  final ResumoEstoque resumo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Total(rotulo: 'Produtos', valor: '${resumo.totalProdutos}'),
                _Total(
                  rotulo: 'Valor em estoque',
                  valor: formatarMoeda(resumo.valorTotal),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Total(
                  rotulo: 'Sem estoque',
                  valor: '${resumo.semEstoque}',
                  cor: resumo.semEstoque > 0 ? AppColors.scoreD : null,
                ),
                _Total(
                  rotulo: 'Estoque baixo',
                  valor: '${resumo.estoqueBaixo}',
                  cor: resumo.estoqueBaixo > 0 ? AppColors.scoreC : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.rotulo, required this.valor, this.cor});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(valor, style: AppTextStyles.money.copyWith(color: cor)),
        ],
      ),
    );
  }
}

class _CardEstoque extends StatelessWidget {
  const _CardEstoque({required this.item});

  final ItemEstoque item;

  @override
  Widget build(BuildContext context) {
    final p = item.produto;
    return ProductCard(
      produto: p,
      selo: SeloSituacaoEstoque(item),
      onTap: () => mostrarDetalheEstoque(
        context,
        item,
        // Liga o ponto de extensão deixado pela KAN-41.
        aoRegistrarEntrada: () =>
            registrarEntradaSheet(context, produtoId: p.id),
      ),
      detalhes: [
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${p.categoria.isEmpty ? 'Sem categoria' : p.categoria} · '
          'mín. ${p.estoqueMinimo}',
          style: AppTextStyles.cardSubtitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Preço ${formatarMoeda(p.preco)} · custo ${formatarMoeda(p.custoAtual)}',
          style: AppTextStyles.cardSubtitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Em estoque ${formatarMoeda(item.valorEmEstoque)}',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
