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

/// Argumento de rota de `AppRoutes.estoque` (KAN-44).
class EstoqueRotaArgs {
  const EstoqueRotaArgs({this.apenasAlertas = false});

  /// Abre a tela já filtrada em alertas.
  final bool apenasAlertas;
}

/// Controle de estoque (KAN-41): consulta do estoque dos produtos, em
/// tempo real e com o cache offline, com resumo, busca e filtros.
///
/// Registrar entrada (KAN-42) e baixa na venda (KAN-43) têm telas e
/// regras próprias. O filtro "Alertas" (KAN-44) mostra os produtos com
/// estoque baixo, sem estoque ou negativo, do mais grave ao menos grave.
///
/// Com [apenasAlertas], a tela abre já nesse filtro (vindo do aviso da
/// aba Produtos). É só o ponto de partida: o filtro continua editável e
/// não fica guardado em estado global.
class EstoqueScreen extends ConsumerStatefulWidget {
  const EstoqueScreen({this.apenasAlertas = false, super.key});

  final bool apenasAlertas;

  /// Monta a tela a partir dos `arguments` da rota (`EstoqueRotaArgs`).
  static Widget daRota(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return EstoqueScreen(
      apenasAlertas: args is EstoqueRotaArgs && args.apenasAlertas,
    );
  }

  @override
  ConsumerState<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends ConsumerState<EstoqueScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.apenasAlertas) {
      // Um provider não pode ser alterado durante o build; o filtro entra
      // logo depois e antes de os dados chegarem (a tela abre carregando).
      Future.microtask(() {
        if (mounted) ref.read(filtroEstoqueProvider.notifier).filtrarAlertas();
      });
    }
  }

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
    // Observado aqui (e não só quando há dados) para o filtro aplicado ao
    // abrir não ser descartado enquanto a lista ainda carrega.
    final filtro = ref.watch(filtroEstoqueProvider);

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
        data: (todos) => _conteudo(todos, filtro),
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

  Widget _conteudo(List<ItemEstoque> todos, FiltroEstoque filtro) {
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

    final notificador = ref.read(filtroEstoqueProvider.notifier);
    final categorias = categoriasDoEstoque(todos);
    final filtrados = filtrarEstoque(
      todos,
      situacao: filtro.situacao,
      categoria: filtro.categoria,
      termo: filtro.termo,
      apenasAlertas: filtro.apenasAlertas,
    );
    // Alertas por gravidade; as demais listas, na ordem da KAN-41.
    final itens = filtro.apenasAlertas
        ? ordenarAlertas(filtrados)
        : ordenarEstoque(filtrados);

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
        FilterChipBar<_FiltroRapido>(
          opcoes: const [
            OpcaoFiltro('Todos', null),
            OpcaoFiltro('Alertas', _FiltroRapido.alertas),
            OpcaoFiltro('Normal', _FiltroRapido.normal),
            OpcaoFiltro('Baixo', _FiltroRapido.baixo),
            OpcaoFiltro('Sem estoque', _FiltroRapido.semEstoque),
          ],
          selecionado: _FiltroRapido.de(filtro),
          onSelecionar: (opcao) => switch (opcao) {
            _FiltroRapido.alertas => notificador.filtrarAlertas(),
            _ => notificador.filtrarPorSituacao(opcao?.situacao),
          },
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
              ? Center(
                  child: SingleChildScrollView(
                    child: _semAlertas(filtro)
                        ? const EmptyState(
                            icone: Icons.check_circle_outline,
                            titulo: 'Nenhum alerta de estoque',
                            descricao:
                                'Todos os produtos estão acima do mínimo.',
                          )
                        : const EmptyState(
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

/// Filtro "Alertas" sozinho, sem busca nem categoria: lista vazia aqui
/// quer dizer que não há alertas, e não que a busca não achou nada.
bool _semAlertas(FiltroEstoque filtro) =>
    filtro.apenasAlertas &&
    filtro.termo.trim().isEmpty &&
    filtro.categoria == null;

/// Chips de situação da barra de filtros: os da KAN-41 mais "Alertas".
enum _FiltroRapido {
  alertas(null),
  normal(SituacaoEstoque.normal),
  baixo(SituacaoEstoque.baixo),
  semEstoque(SituacaoEstoque.semEstoque);

  const _FiltroRapido(this.situacao);

  final SituacaoEstoque? situacao;

  static _FiltroRapido? de(FiltroEstoque filtro) {
    if (filtro.apenasAlertas) return alertas;
    return switch (filtro.situacao) {
      SituacaoEstoque.normal => normal,
      SituacaoEstoque.baixo => baixo,
      SituacaoEstoque.semEstoque => semEstoque,
      null => null,
    };
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
    final textoFalta = textoFaltaParaMinimo(item);
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
        if (textoFalta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            textoFalta,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusInadimplente,
            ),
          ),
        ],
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
