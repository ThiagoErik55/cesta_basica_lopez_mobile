import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/despesa_model.dart';
import '../domain/formulario_despesa.dart';
import 'despesa_form_sheet.dart';
import 'despesa_providers.dart';
import 'dia_financeiro_provider.dart';
import 'seletor_dia.dart';

/// Despesas do vendedor (RF27, KAN-50): lista do dia selecionado, com
/// total, lançamento, edição e exclusão. Aberta pelo Financeiro.
class DespesasScreen extends ConsumerWidget {
  const DespesasScreen({super.key});

  Future<void> _remover(
    BuildContext context,
    WidgetRef ref,
    DespesaModel despesa,
  ) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir despesa',
      mensagem:
          'Excluir "${despesa.descricao}" de '
          '${formatarMoeda(despesa.valor)}?',
      textoConfirmar: 'Excluir',
      destrutiva: true,
    );
    if (!confirmado || !context.mounted) return;

    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(salvarDespesaProvider.notifier)
          .remover(despesa);
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            'Despesa excluída.'
            '${sincronizado ? '' : ' Será enviada quando houver conexão.'}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao excluir despesa: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível excluir. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final despesas = ref.watch(despesasDoDiaProvider);
    final dia = ref.watch(diaFinanceiroProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novaDespesa',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textoContrastante(AppColors.primary),
        onPressed: () => abrirFormularioDespesa(context, dia: dia),
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SeletorDia(),
          ),
          Expanded(
            child: despesas.when(
              skipLoadingOnReload: true,
              data: (lista) => lista.isEmpty
                  ? const Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icone: Icons.receipt_outlined,
                          titulo: 'Nenhuma despesa neste dia',
                          descricao:
                              'Toque em "Nova despesa" para lançar um gasto, '
                              'como combustível ou alimentação.',
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        // Espaço para o botão não cobrir o último item.
                        AppSpacing.xl * 3,
                      ),
                      children: [
                        _CardTotal(
                          total: totalDespesas(lista),
                          quantidade: lista.length,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Card(
                          child: Column(
                            children: [
                              for (final (i, despesa) in lista.indexed) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                _ItemDespesa(
                                  despesa: despesa,
                                  onEditar: () => abrirFormularioDespesa(
                                    context,
                                    despesa: despesa,
                                    dia: dia,
                                  ),
                                  onExcluir: () =>
                                      _remover(context, ref, despesa),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao carregar despesas: $error');
                return const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao carregar despesas',
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
}

class _CardTotal extends StatelessWidget {
  const _CardTotal({required this.total, required this.quantidade});

  final double total;
  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                quantidade == 1
                    ? 'Total (1 despesa)'
                    : 'Total ($quantidade despesas)',
                style: AppTextStyles.body,
              ),
            ),
            Text(
              formatarMoeda(total),
              style: AppTextStyles.moneyLarge.copyWith(
                color: AppColors.statusInadimplente,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDespesa extends StatelessWidget {
  const _ItemDespesa({
    required this.despesa,
    required this.onEditar,
    required this.onExcluir,
  });

  final DespesaModel despesa;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onEditar,
      title: Text(despesa.descricao, style: AppTextStyles.cardTitle),
      subtitle: Text(
        formatarDataHora(despesa.data),
        style: AppTextStyles.cardSubtitle,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatarMoeda(despesa.valor), style: AppTextStyles.money),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: onExcluir,
          ),
        ],
      ),
    );
  }
}
