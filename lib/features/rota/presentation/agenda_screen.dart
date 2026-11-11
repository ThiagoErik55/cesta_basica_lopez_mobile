import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/client_card.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../auth/presentation/logout_button.dart';
import '../domain/agenda_vendedor.dart';
import 'acoes_rapidas_cliente.dart';
import 'agenda_providers.dart';

/// Aba de agenda do vendedor (RF08, RF09, KAN-47): o vendedor escolhe uma
/// data e uma rota e vê os clientes daquela rota, com o que está vencendo
/// ou vencido na data. É tudo derivado de clientes, rotas e parcelas: a
/// agenda não grava nada.
///
/// Pontos de extensão:
/// - [recomendados]: espaço no topo para o bloco "Recomendados para
///   visitar" da KAN-48, que o preenche. Sem ele, não ocupa espaço.
/// - [aoMarcarVisitaRealizada]: se um dia existir persistência de visita
///   (hoje a agenda não grava nada), ligar este callback faz aparecer o
///   botão "Visita realizada" em cada cliente.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({
    this.recomendados,
    this.aoMarcarVisitaRealizada,
    super.key,
  });

  final Widget? recomendados;
  final ValueChanged<ItemAgenda>? aoMarcarVisitaRealizada;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
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
      if (mounted) ref.read(selecaoAgendaProvider.notifier).buscar(texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    ref.read(selecaoAgendaProvider.notifier).buscar('');
  }

  Future<void> _escolherData() async {
    final selecao = ref.read(selecaoAgendaProvider);
    final hoje = soData(ref.read(agendaRelogioProvider)());
    final escolhida = await showDatePicker(
      context: context,
      initialDate: selecao.data,
      firstDate: DateTime(hoje.year - 2),
      lastDate: DateTime(hoje.year + 2, 12, 31),
      helpText: 'Data da agenda',
    );
    if (escolhida != null && mounted) {
      ref.read(selecaoAgendaProvider.notifier).escolherData(escolhida);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selecao = ref.watch(selecaoAgendaProvider);
    final notificador = ref.read(selecaoAgendaProvider.notifier);
    final agenda = ref.watch(agendaProvider);
    final hoje = soData(ref.watch(agendaRelogioProvider)());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          // Cadastro de rotas (KAN-45): as rotas organizam a agenda.
          IconButton(
            tooltip: 'Rotas',
            icon: const Icon(Icons.route_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.rotas),
          ),
          const LogoutButton(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: Column(
        children: [
          _SeletorData(
            data: selecao.data,
            ehHoje: selecao.data == hoje,
            onAnterior: notificador.diaAnterior,
            onProximo: notificador.proximoDia,
            onHoje: notificador.irParaHoje,
            onEscolher: _escolherData,
          ),
          Expanded(
            child: agenda.when(
              data: (dados) => _conteudo(dados, selecao),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao carregar a agenda: $error');
                return const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao carregar a agenda',
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

  Widget _conteudo(AgendaDoDia agenda, SelecaoAgenda selecao) {
    final notificador = ref.read(selecaoAgendaProvider.notifier);

    final topo = <Widget>[
      if (agenda.rotas.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: FilterChipBar<String>(
            opcoes: [
              const OpcaoFiltro('Todas as rotas', null),
              for (final r
                  in ([...agenda.rotas]..sort(
                    (a, b) =>
                        a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
                  )))
                OpcaoFiltro(r.nome, r.id),
            ],
            selecionado: agenda.rotaId,
            onSelecionar: notificador.escolherRota,
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: _ResumoDoDia(
          resumo: agenda.resumo,
          parcelasDisponiveis: agenda.parcelasDisponiveis,
        ),
      ),
      // KAN-48 preenche este espaço com "Recomendados para visitar".
      if (widget.recomendados != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: widget.recomendados,
        ),
    ];

    if (agenda.itens.isEmpty) {
      return ListView(
        children: [
          ...topo,
          EmptyState(
            icone: Icons.event_busy_outlined,
            titulo: agenda.rotaId == null
                ? 'Nenhum cliente na agenda'
                : 'Nenhum cliente nesta rota',
            descricao: agenda.rotaId == null
                ? 'Cadastre clientes na aba Clientes.'
                : 'Associe clientes a esta rota no cadastro de rotas.',
          ),
        ],
      );
    }

    final visiveis = filtrarAgenda(
      agenda.itens,
      filtro: selecao.filtro,
      termo: selecao.termo,
    );
    // Todas as rotas: um grupo por rota (e "Sem rota"); uma rota: lista
    // simples.
    final grupos = agenda.rotaId == null
        ? agruparAgendaPorRota(visiveis)
        : [
            GrupoAgenda(
              rotaId: agenda.rotaId,
              titulo: '',
              itens: ordenarAgenda(visiveis),
            ),
          ];

    final linhas = <Widget>[
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
              hintText: 'Buscar cliente pelo nome',
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
      FilterChipBar<FiltroAgenda>(
        opcoes: [for (final f in FiltroAgenda.values) OpcaoFiltro(f.rotulo, f)],
        selecionado: selecao.filtro,
        onSelecionar: (f) => notificador.filtrar(f ?? FiltroAgenda.todos),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (visiveis.isEmpty)
        const EmptyState(
          icone: Icons.search_off,
          titulo: 'Nenhum cliente encontrado',
          descricao: 'Ajuste a busca ou o filtro.',
        ),
      for (final g in grupos) ...[
        if (g.titulo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              '${g.titulo} · ${g.itens.length}',
              style: AppTextStyles.sectionTitle,
            ),
          ),
        for (final item in g.itens)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: _CartaoAgenda(
              item: item,
              aoMarcarVisitaRealizada: widget.aoMarcarVisitaRealizada,
            ),
          ),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl * 3),
      children: [...topo, ...linhas],
    );
  }
}

class _SeletorData extends StatelessWidget {
  const _SeletorData({
    required this.data,
    required this.ehHoje,
    required this.onAnterior,
    required this.onProximo,
    required this.onHoje,
    required this.onEscolher,
  });

  final DateTime data;
  final bool ehHoje;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final VoidCallback onHoje;
  final VoidCallback onEscolher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Dia anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: onAnterior,
          ),
          Expanded(
            child: InkWell(
              onTap: onEscolher,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    Text(
                      rotuloDaData(data),
                      style: AppTextStyles.cardTitle,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      ehHoje
                          ? 'Hoje · toque para escolher'
                          : 'Toque para escolher',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!ehHoje) TextButton(onPressed: onHoje, child: const Text('Hoje')),
          IconButton(
            tooltip: 'Próximo dia',
            icon: const Icon(Icons.chevron_right),
            onPressed: onProximo,
          ),
        ],
      ),
    );
  }
}

class _ResumoDoDia extends StatelessWidget {
  const _ResumoDoDia({required this.resumo, required this.parcelasDisponiveis});

  final ResumoAgenda resumo;
  final bool parcelasDisponiveis;

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
                _Total(rotulo: 'Clientes', valor: '${resumo.totalClientes}'),
                _Total(
                  rotulo: 'Vencem na data',
                  valor: '${resumo.vencendoNaData}',
                  cor: resumo.vencendoNaData > 0 ? AppColors.scoreC : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Total(
                  rotulo: 'Em atraso',
                  valor: '${resumo.emAtraso}',
                  cor: resumo.emAtraso > 0 ? AppColors.scoreD : null,
                ),
                _Total(
                  rotulo: 'A receber',
                  valor: resumo.valoresExatos && parcelasDisponiveis
                      ? formatarMoeda(resumo.aReceber)
                      : '—',
                ),
              ],
            ),
            if (!parcelasDisponiveis) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Carregando as parcelas… os valores aparecem em seguida.',
                style: AppTextStyles.caption,
              ),
            ],
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

class _CartaoAgenda extends StatelessWidget {
  const _CartaoAgenda({
    required this.item,
    required this.aoMarcarVisitaRealizada,
  });

  final ItemAgenda item;
  final ValueChanged<ItemAgenda>? aoMarcarVisitaRealizada;

  @override
  Widget build(BuildContext context) {
    final c = item.cliente;
    final destaques = destaquesDaAgenda(item);
    void abrirDetalhe() =>
        Navigator.of(context)
            .pushNamed(AppRoutes.detalheCliente, arguments: c.id);

    return ClientCard(
      cliente: c,
      situacao: item.situacao,
      rotaNome: item.rotaNome,
      onTap: abrirDetalhe,
      detalhes: [
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Em aberto ${formatarMoeda(c.valorEmAberto)} · '
          'próx. venc. ${formatarData(c.proximoVencimento)}',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Última compra ${formatarData(c.ultimaCompra, vazio: 'nenhuma')}',
          style: AppTextStyles.caption,
        ),
        if (item.valoresPorParcela && item.aReceber > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A receber até a data ${formatarMoeda(item.aReceber)}',
            style: AppTextStyles.caption,
          ),
        ],
        for (final d in destaques) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            d,
            style: AppTextStyles.cardSubtitle.copyWith(
              color: item.vencida
                  ? AppColors.statusInadimplente
                  : AppColors.statusAtencao,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
      rodape: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: AcoesRapidasCliente(
          cliente: c,
          extras: [
            if (aoMarcarVisitaRealizada != null)
              TextButton.icon(
                onPressed: () => aoMarcarVisitaRealizada!(item),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Visita realizada'),
              ),
          ],
        ),
      ),
    );
  }
}
