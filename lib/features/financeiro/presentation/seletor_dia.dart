import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/dia.dart';
import 'dia_financeiro_provider.dart';

/// Troca o dia exibido no financeiro: setas para o dia anterior e o
/// seguinte, e toque na data para escolher no calendário.
class SeletorDia extends ConsumerWidget {
  const SeletorDia({super.key});

  Future<void> _escolher(BuildContext context, WidgetRef ref) async {
    final hoje = inicioDoDia(DateTime.now());
    final escolhido = await showDatePicker(
      context: context,
      initialDate: ref.read(diaFinanceiroProvider),
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: hoje,
      helpText: 'Escolha o dia',
    );
    if (escolhido != null) {
      ref.read(diaFinanceiroProvider.notifier).selecionar(escolhido);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dia = ref.watch(diaFinanceiroProvider);
    final notifier = ref.read(diaFinanceiroProvider.notifier);
    final ehHoje = mesmoDia(dia, DateTime.now());

    return Row(
      children: [
        IconButton(
          tooltip: 'Dia anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: notifier.anterior,
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () => _escolher(context, ref),
            icon: const Icon(Icons.event),
            label: Text(
              ehHoje ? 'Hoje, ${formatarData(dia)}' : formatarData(dia),
              style: AppTextStyles.cardTitle,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Dia seguinte',
          icon: const Icon(Icons.chevron_right),
          onPressed: ehHoje ? null : notifier.proximo,
        ),
        if (!ehHoje)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: TextButton(
              onPressed: notifier.hoje,
              child: const Text('Hoje'),
            ),
          ),
      ],
    );
  }
}