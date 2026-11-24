import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../domain/periodo.dart';
import 'periodo_financeiro_provider.dart';

/// Escolha do período do painel (KAN-52): Hoje, Semana, Mês ou
/// Personalizado, com o intervalo escrito logo abaixo.
class SeletorPeriodo extends ConsumerWidget {
  const SeletorPeriodo({super.key});

  Future<void> _personalizar(BuildContext context, WidgetRef ref) async {
    final atual = ref.read(periodoFinanceiroProvider);
    final hoje = DateTime.now();
    final escolhido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoje.year - 2, hoje.month, hoje.day),
      lastDate: hoje,
      initialDateRange: DateTimeRange(
        start: atual.inicio,
        end: atual.ultimoDia.isAfter(hoje) ? hoje : atual.ultimoDia,
      ),
      helpText: 'Escolha o período',
    );
    if (escolhido == null || !context.mounted) return;
    ref
        .read(periodoFinanceiroProvider.notifier)
        .personalizar(escolhido.start, escolhido.end);
    final dias = escolhido.end.difference(escolhido.start).inDays + 1;
    if (dias > maximoDiasPersonalizado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Período limitado a $maximoDiasPersonalizado dias. '
            'O fim foi ajustado.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoFinanceiroProvider);
    final intervalo = periodo.dias == 1
        ? formatarData(periodo.inicio)
        : '${formatarData(periodo.inicio)} a ${formatarData(periodo.ultimoDia)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterChipBar<TipoPeriodo>(
          opcoes: const [
            OpcaoFiltro('Hoje', TipoPeriodo.hoje),
            OpcaoFiltro('Semana', TipoPeriodo.semana),
            OpcaoFiltro('Mês', TipoPeriodo.mes),
            OpcaoFiltro('Personalizado', TipoPeriodo.personalizado),
          ],
          selecionado: periodo.tipo,
          onSelecionar: (tipo) {
            if (tipo == null) return;
            if (tipo == TipoPeriodo.personalizado) {
              _personalizar(context, ref);
            } else {
              ref.read(periodoFinanceiroProvider.notifier).selecionar(tipo);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Text(intervalo, style: AppTextStyles.caption),
        ),
      ],
    );
  }
}
