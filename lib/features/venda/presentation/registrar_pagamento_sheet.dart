import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../domain/registro_pagamento.dart';
import '../domain/rotulos_venda.dart';
import 'pos_venda_providers.dart';

/// Registro de pagamento, total ou parcial, de uma parcela pendente
/// (RF16, KAN-33).
Future<void> registrarPagamentoSheet(
  BuildContext context, {
  required VendaModel venda,
  required ParcelaModel parcela,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RegistrarPagamentoSheet(venda: venda, parcelaId: parcela.id),
);

class _RegistrarPagamentoSheet extends ConsumerStatefulWidget {
  const _RegistrarPagamentoSheet({
    required this.venda,
    required this.parcelaId,
  });

  final VendaModel venda;
  final String parcelaId;

  @override
  ConsumerState<_RegistrarPagamentoSheet> createState() =>
      _RegistrarPagamentoSheetState();
}

class _RegistrarPagamentoSheetState
    extends ConsumerState<_RegistrarPagamentoSheet> {
  final _valor = TextEditingController();
  final _observacao = TextEditingController();
  FormaPagamento? _forma;
  DateTime _data = DateTime.now();
  bool _inicializado = false;

  @override
  void dispose() {
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      helpText: 'Data do pagamento',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _confirmar(List<ParcelaModel> parcelas) async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(posVendaProvider.notifier)
          .registrarPagamentoDaParcela(
            venda: widget.venda,
            parcelas: parcelas,
            parcelaId: widget.parcelaId,
            valor: lerValorMonetario(_valor.text)!,
            forma: _forma!,
            data: _data,
            observacao: _observacao.text,
          );
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Pagamento registrado.'
                : 'Pagamento salvo no aparelho. Será enviado quando houver '
                      'conexão.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao registrar pagamento: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível registrar o pagamento. Tente de novo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelas =
        ref.watch(parcelasDaVendaProvider(widget.venda.id)).value ?? const [];
    final parcela = parcelas.where((p) => p.id == widget.parcelaId).firstOrNull;
    final salvando = ref.watch(posVendaProvider).isLoading;

    if (parcela == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('Parcela não encontrada.', style: AppTextStyles.body),
      );
    }

    if (!_inicializado) {
      _valor.text = formatarValorEditavel(parcela.saldo);
      _inicializado = true;
    }

    final valor = lerValorMonetario(_valor.text);
    final resultado = valor == null
        ? null
        : registrarPagamentoParcela(
            parcelasDaVenda: parcelas,
            parcelaId: widget.parcelaId,
            valor: valor,
            forma: _forma ?? FormaPagamento.dinheiro,
            data: _data,
          );
    final erro = resultado?.erro;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar pagamento da ${parcela.numero}ª parcela',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vence em ${formatarData(parcela.vencimento)} · saldo '
              '${formatarMoeda(parcela.saldo)}',
              style: AppTextStyles.cardSubtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [valorMonetarioFormatter],
              decoration: const InputDecoration(
                labelText: 'Valor pago',
                prefixText: r'R$ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<FormaPagamento>(
              initialValue: _forma,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
              ),
              items: [
                for (final f in FormaPagamento.values)
                  DropdownMenuItem(value: f, child: Text(f.rotulo)),
              ],
              onChanged: (f) => setState(() => _forma = f),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Text('Data do pagamento', style: AppTextStyles.body),
                ),
                TextButton.icon(
                  onPressed: _escolherData,
                  icon: const Icon(Icons.event),
                  label: Text(formatarData(_data)),
                ),
              ],
            ),
            TextField(
              controller: _observacao,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (erro != null)
              Text(
                erro,
                style: AppTextStyles.body.copyWith(color: AppColors.scoreD),
              )
            else if (resultado != null)
              Text(
                resultado.parcelaQuitada
                    ? 'A parcela será quitada.'
                    : 'Pagamento parcial: a parcela continua pendente com '
                          'saldo de ${formatarMoeda(resultado.saldoRestante)}.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              texto: 'Confirmar pagamento',
              carregando: salvando,
              onPressed: resultado != null && resultado.ok && _forma != null
                  ? () => _confirmar(parcelas)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
