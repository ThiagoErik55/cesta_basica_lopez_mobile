import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/client_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../domain/recomendacao_visita.dart';
import 'acoes_rapidas_cliente.dart';
import 'recomendacao_providers.dart';
import 'recomendados_para_visitar.dart';

/// Abre a lista completa de recomendados, por prioridade (KAN-48).
Future<void> mostrarRecomendacoes(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecomendacoesSheet(),
    );

class RecomendacoesSheet extends ConsumerStatefulWidget {
  const RecomendacoesSheet({super.key});

  @override
  ConsumerState<RecomendacoesSheet> createState() => _RecomendacoesSheetState();
}

class _RecomendacoesSheetState extends ConsumerState<RecomendacoesSheet> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
  Timer? _timer;
  String _termo = '';
  MotivoVisita? _motivo;

  @override
  void dispose() {
    _timer?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) setState(() => _termo = texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    setState(() => _termo = '');
  }

  @override
  Widget build(BuildContext context) {
    final recomendacoes = ref.watch(recomendacoesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => recomendacoes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: EmptyState(
            icone: Icons.error_outline,
            titulo: 'Erro ao carregar as recomendações',
            descricao: 'Verifique a conexão e tente novamente.',
          ),
        ),
        data: (dados) => _conteudo(dados, scroll),
      ),
    );
  }

  Widget _conteudo(RecomendacoesDoDia dados, ScrollController scroll) {
    // Se o motivo escolhido deixou de existir (ex. cliente dispensado ou
    // pago), volta para "Todos".
    final motivos = motivosPresentes(dados.todas);
    final motivo = motivos.contains(_motivo) ? _motivo : null;
    final lista = filtrarRecomendacoes(
      dados.todas,
      motivo: motivo,
      termo: _termo,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recomendados para visitar · ${dados.todas.length}',
              style: AppTextStyles.sectionTitle,
            ),
          ),
        ),
        if (dados.dispensados > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dados.dispensados == 1
                        ? '1 cliente dispensado hoje'
                        : '${dados.dispensados} clientes dispensados hoje',
                    style: AppTextStyles.caption,
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(dispensadosHojeProvider.notifier)
                      .restaurar(dados.data),
                  child: const Text('Desfazer'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.sm),
        if (motivos.length > 1)
          FilterChipBar<MotivoVisita>(
            opcoes: [
              const OpcaoFiltro('Todos', null),
              for (final m in motivos) OpcaoFiltro(m.rotulo, m),
            ],
            selecionado: motivo,
            onSelecionar: (m) => setState(() => _motivo = m),
          ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: dados.todas.isEmpty
              ? const Center(
                  child: EmptyState(
                    icone: Icons.check_circle_outline,
                    titulo: 'Nenhum cliente para visitar agora',
                    descricao:
                        'Ninguém com cobrança pendente ou sem comprar há '
                        'muito tempo.',
                  ),
                )
              : lista.isEmpty
              ? const Center(
                  child: EmptyState(
                    icone: Icons.search_off,
                    titulo: 'Nenhum cliente encontrado',
                    descricao: 'Ajuste a busca ou o filtro.',
                  ),
                )
              : ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CartaoRecomendado(
                    recomendacao: lista[i],
                    data: dados.data,
                  ),
                ),
        ),
      ],
    );
  }
}

class _CartaoRecomendado extends ConsumerWidget {
  const _CartaoRecomendado({required this.recomendacao, required this.data});

  final Recomendacao recomendacao;
  final DateTime data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = recomendacao.item;
    final c = item.cliente;

    return ClientCard(
      cliente: c,
      situacao: item.situacao,
      rotaNome: item.rotaNome,
      onTap: () =>
          Navigator.of(context)
              .pushNamed(AppRoutes.detalheCliente, arguments: c.id),
      detalhes: [
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: SeloMotivoVisita(recomendacao.motivo),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(recomendacao.textoMotivo, style: AppTextStyles.caption),
      ],
      rodape: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: AcoesRapidasCliente(
          cliente: c,
          extras: [
            TextButton.icon(
              onPressed: () => ref
                  .read(dispensadosHojeProvider.notifier)
                  .dispensar(c.id, data),
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Dispensar hoje'),
            ),
          ],
        ),
      ),
    );
  }
}
