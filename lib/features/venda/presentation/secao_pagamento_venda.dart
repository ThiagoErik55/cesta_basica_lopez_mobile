import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/section_header.dart';
import '../data/parcela_model.dart';
import '../domain/calculo_parcelas.dart';
import '../domain/rotulos_venda.dart';
import 'nova_venda_providers.dart';

/// Forma de pagamento: à vista ou parcelado (KAN-26).
class SecaoPagamentoVenda extends ConsumerWidget {
  const SecaoPagamentoVenda({required this.venda, super.key});

  final NovaVendaState venda;

  static const _maximoParcelas = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(novaVendaProvider.notifier);
    final permiteParcelado = venda.pendencia?.permiteParcelado ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(titulo: 'Pagamento'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final forma in FormaPagamento.values)
              _OpcaoPagamentoChip(
                rotulo: forma.rotulo,
                icone: _iconeForma(forma),
                selecionado: venda.pagamento == PagamentoAVista(forma),
                onTap: () =>
                    notifier.selecionarPagamento(PagamentoAVista(forma)),
              ),
            _OpcaoPagamentoChip(
              rotulo: 'Parcelado',
              icone: Icons.receipt_long_outlined,
              selecionado: venda.parcelado,
              onTap: permiteParcelado
                  ? () =>
                        notifier.selecionarPagamento(const PagamentoParcelado())
                  : null,
            ),
          ],
        ),
        if (!permiteParcelado) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Parcelado indisponível para cliente bloqueado.',
            style: AppTextStyles.caption,
          ),
        ],
        if (venda.parcelado) ...[
          const SizedBox(height: AppSpacing.md),
          _ConfiguracaoParcelas(venda: venda, maximo: _maximoParcelas),
        ],
      ],
    );
  }

  IconData _iconeForma(FormaPagamento forma) => switch (forma) {
    FormaPagamento.pix => Icons.qr_code_2,
    FormaPagamento.credito => Icons.credit_card,
    FormaPagamento.debito => Icons.credit_card_outlined,
    FormaPagamento.valeAlimentacao => Icons.restaurant_outlined,
    FormaPagamento.dinheiro => Icons.payments_outlined,
  };
}

class _OpcaoPagamentoChip extends StatelessWidget {
  const _OpcaoPagamentoChip({
    required this.rotulo,
    required this.icone,
    required this.selecionado,
    required this.onTap,
  });

  final String rotulo;
  final IconData icone;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    final corTexto = !habilitado
        ? AppColors.textSecondary
        : selecionado
        ? AppColors.textoContrastante(AppColors.primary)
        : AppColors.textPrimary;

    return ChoiceChip(
      avatar: Icon(icone, size: AppSpacing.md + AppSpacing.xs, color: corTexto),
      label: Text(rotulo),
      selected: selecionado,
      onSelected: habilitado ? (_) => onTap!() : null,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      labelStyle: AppTextStyles.body.copyWith(color: corTexto),
    );
  }
}

class _ConfiguracaoParcelas extends ConsumerWidget {
  const _ConfiguracaoParcelas({required this.venda, required this.maximo});

  final NovaVendaState venda;
  final int maximo;

  Future<void> _escolherData(BuildContext context, WidgetRef ref) async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: venda.primeiroVencimento,
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Primeiro vencimento',
    );
    if (data != null) {
      ref.read(novaVendaProvider.notifier).definirPrimeiroVencimento(data);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(novaVendaProvider.notifier);
    // Prévia só para exibição; as parcelas de verdade são geradas ao
    // finalizar.
    final previa = venda.total > 0
        ? gerarParcelas(
            vendaId: '',
            total: venda.total,
            quantidade: venda.numeroParcelas,
            primeiroVencimento: venda.primeiroVencimento,
          )
        : const <ParcelaModel>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Parcelas', style: AppTextStyles.body),
                ),
                DropdownButton<int>(
                  value: venda.numeroParcelas,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var n = minimoParcelas; n <= maximo; n++)
                      DropdownMenuItem(value: n, child: Text('${n}x')),
                  ],
                  onChanged: (n) {
                    if (n != null) notifier.definirNumeroParcelas(n);
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('1º vencimento', style: AppTextStyles.body),
                ),
                TextButton.icon(
                  onPressed: () => _escolherData(context, ref),
                  icon: const Icon(Icons.event),
                  label: Text(formatarData(venda.primeiroVencimento)),
                ),
              ],
            ),
            if (previa.isNotEmpty) ...[
              const Divider(color: AppColors.border),
              for (final p in previa)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p.numero}ª · ${formatarData(p.vencimento)}',
                          style: AppTextStyles.cardSubtitle,
                        ),
                      ),
                      Text(formatarMoeda(p.valor), style: AppTextStyles.body),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
