import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/semana.dart';
import 'relatorio_semanal_providers.dart';

/// Escolha da semana do relatório (KAN-53): anterior, próxima (travada
/// na semana corrente), "Esta semana" e calendário para a semana de
/// qualquer data. Segunda a domingo, dias de calendário locais.
class SeletorSemana extends ConsumerWidget {
  const SeletorSemana({super.key});

  Future<void> _escolherData(BuildContext context, WidgetRef ref) async {
    final semana = ref.read(semanaRelatorioProvider);
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: semana.inicio.isAfter(hoje) ? hoje : semana.inicio,
      firstDate: DateTime(hoje.year - 2, hoje.month, hoje.day),
      lastDate: hoje,
      helpText: 'Escolha um dia da semana',
    );
    if (data == null) return;
    ref.read(semanaRelatorioProvider.notifier).escolherData(data);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semana = ref.watch(semanaRelatorioProvider);
    final notificador = ref.read(semanaRelatorioProvider.notifier);
    final corrente = ehSemanaCorrente(semana, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: notificador.anterior,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${formatarData(semana.inicio)} a '
                  '${formatarData(semana.ultimoDia)}',
                  style: AppTextStyles.cardTitle,
                ),
                Text(
                  corrente ? 'Esta semana' : 'Segunda a domingo',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Próxima semana',
            icon: const Icon(Icons.chevron_right),
            onPressed: corrente ? null : notificador.proxima,
          ),
          IconButton(
            tooltip: 'Escolher a semana de uma data',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _escolherData(context, ref),
          ),
          TextButton(
            onPressed: corrente ? null : notificador.estaSemana,
            child: const Text('Esta semana'),
          ),
        ],
      ),
    );
  }
}
