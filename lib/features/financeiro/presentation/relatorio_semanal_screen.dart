import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/compartilhador_pdf.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../data/relatorio_semanal_pdf.dart';
import '../domain/relatorio_linha.dart';
import 'detalhe_linha_sheet.dart';
import 'grafico_barras_linhas.dart';
import 'painel_indicadores.dart';
import 'relatorio_semanal_providers.dart';
import 'relatorio_tabela.dart';
import 'seletor_semana.dart';

/// Relatório semanal por linha de atendimento (KAN-53): resultado da
/// semana por linha, comparação com a semana anterior, gráfico, detalhe
/// por linha e PDF para compartilhar.
///
/// Os números são do vendedor logado, como no painel da KAN-52, e a linha
/// de cada venda vem da rota atual do cliente (ver `relatorio_linha.dart`).
class RelatorioSemanalScreen extends ConsumerStatefulWidget {
  const RelatorioSemanalScreen({super.key});

  @override
  ConsumerState<RelatorioSemanalScreen> createState() =>
      _RelatorioSemanalScreenState();
}

class _RelatorioSemanalScreenState
    extends ConsumerState<RelatorioSemanalScreen> {
  bool _gerandoPdf = false;

  Future<void> _compartilharPdf(RelatorioSemanal relatorio) async {
    final mensageiro = ScaffoldMessenger.of(context);
    final vendedor = ref.read(vendedorDoRelatorioProvider);
    final compartilhador = ref.read(compartilhadorPdfProvider);
    setState(() => _gerandoPdf = true);
    try {
      final bytes = await gerarPdfRelatorioSemanal(
        relatorio,
        vendedor: vendedor,
        geradoEm: DateTime.now(),
      );
      await compartilhador.compartilhar(
        bytes: bytes,
        nomeArquivo: nomeArquivoRelatorioSemanal(relatorio.semana),
      );
    } catch (e, st) {
      debugPrint('Erro ao compartilhar o relatório semanal: $e\n$st');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar o PDF do relatório.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatorio = ref.watch(relatorioSemanalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório semanal'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: Column(
        children: [
          const SeletorSemana(),
          Expanded(
            child: relatorio.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao montar o relatório semanal: $error');
                return const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao carregar o relatório',
                    descricao: 'Verifique a conexão e tente novamente.',
                  ),
                );
              },
              data: (r) => _Conteudo(relatorio: r),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(
                texto: 'Compartilhar PDF',
                carregando: _gerandoPdf,
                onPressed: relatorio.value == null
                    ? null
                    : () => _compartilharPdf(relatorio.value!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.relatorio});

  final RelatorioSemanal relatorio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendedor = ref.watch(vendedorDoRelatorioProvider);
    final r = relatorio;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Vendedor: $vendedor', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Linha pela rota atual do cliente: se o cliente mudar de rota, '
          'as vendas antigas passam para a linha nova. Clientes sem rota '
          'ficam em "Sem linha".',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (r.vazio) ...[
          Text(
            'Sem vendas, recebimentos nem despesas nesta semana. A tabela '
            'aparece zerada.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusAtencao,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        RelatorioTabela(
          relatorio: r,
          aoAbrirLinha: (linha) =>
              mostrarDetalheLinha(context, linha: linha, semana: r.semana),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Toque numa linha para ver o detalhe. Despesas não têm linha e '
          'ficam abaixo.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(titulo: 'Resultado da semana'),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CartaoIndicador(
                  rotulo: 'DESPESAS GERAIS',
                  valor: formatarCentavos(r.despesasGerais),
                  detalhe: 'Não atribuídas a linha',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: CartaoIndicador(
                  rotulo: 'LUCRO LÍQUIDO',
                  valor: formatarCentavos(r.lucroLiquido),
                  detalhe: 'Lucro bruto − despesas',
                  destaque: true,
                ),
              ),
            ],
          ),
        ),
        if (r.total.itensSemCusto > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            r.total.itensSemCusto == 1
                ? '1 item vendido está sem custo cadastrado: o lucro '
                      'aparece maior que o real.'
                : '${r.total.itensSemCusto} itens vendidos estão sem custo '
                      'cadastrado: o lucro aparece maior que o real.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusAtencao,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(titulo: 'Faturamento e lucro por linha'),
        const SizedBox(height: AppSpacing.sm),
        GraficoBarrasLinhas(linhas: r.linhas),
      ],
    );
  }
}
