import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../domain/alteracao_parcela.dart';
import 'pos_venda_providers.dart';

/// Alteração do valor de uma parcela pendente (RF15, KAN-32).
Future<void> alterarValorParcelaSheet(
  BuildContext context, {
  required VendaModel venda,
  required ParcelaModel parcela,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AlterarValorSheet(venda: venda, parcelaId: parcela.id),
);

class _AlterarValorSheet extends ConsumerStatefulWidget {
  const _AlterarValorSheet({required this.venda, required this.parcelaId});

  final VendaModel venda;
  final String parcelaId;

  @override
  ConsumerState<_AlterarValorSheet> createState() => _AlterarValorSheetState();
}

class _AlterarValorSheetState extends ConsumerState<_AlterarValorSheet> {
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  ModoCompensacao _modo = ModoCompensacao.redistribuir;
  bool _inicializado = false;

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  bool _temOutrasPendentes(List<ParcelaModel> parcelas) =>
      parcelas.any((p) => !p.pago && !p.deleted && p.id != widget.parcelaId);

  ResultadoAlteracaoParcela? _calcular(List<ParcelaModel> parcelas) {
    final novo = lerValorMonetario(_valor.text);
    if (novo == null) return null;
    return alterarValorParcela(
      parcelas: parcelas,
      parcelaId: widget.parcelaId,
      novoValor: novo,
      modo: _modo,
      valorTotalVenda: widget.venda.valorTotal,
      motivo: _motivo.text,
    );
  }

  Future<void> _confirmar(
    List<ParcelaModel> parcelas,
    ResultadoAlteracaoParcela resultado,
  ) async {
    if (_modo == ModoCompensacao.ajustarSomente) {
      final aceito = await confirmar(
        context,
        titulo: 'Alterar o total da venda?',
        mensagem:
            'Só esta parcela será alterada e o total da venda muda de '
            '${formatarMoeda(resultado.totalAnterior)} para '
            '${formatarMoeda(resultado.totalNovo)}.',
        textoConfirmar: 'Alterar total',
      );
      if (!aceito || !mounted) return;
    }

    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(posVendaProvider.notifier)
          .registrarAlteracaoParcela(
            venda: widget.venda,
            parcelas: parcelas,
            parcelaId: widget.parcelaId,
            novoValor: lerValorMonetario(_valor.text)!,
            modo: _modo,
            motivo: _motivo.text,
          );
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Valor da parcela alterado.'
                : 'Alteração salva no aparelho. Será enviada quando houver '
                      'conexão.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao alterar valor da parcela: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar a parcela. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelas =
        ref.watch(parcelasDaVendaProvider(widget.venda.id)).value ?? const [];
    final alvo = parcelas.where((p) => p.id == widget.parcelaId).firstOrNull;
    final salvando = ref.watch(posVendaProvider).isLoading;

    if (alvo == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('Parcela não encontrada.', style: AppTextStyles.body),
      );
    }

    if (!_inicializado) {
      _valor.text = formatarValorEditavel(alvo.valor);
      _inicializado = true;
    }

    final podeRedistribuir = _temOutrasPendentes(parcelas);
    final modo = podeRedistribuir ? _modo : ModoCompensacao.ajustarSomente;
    if (modo != _modo) _modo = modo;

    final resultado = _calcular(parcelas);
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
              'Alterar valor da ${alvo.numero}ª parcela',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vence em ${formatarData(alvo.vencimento)} · '
              'valor atual ${formatarMoeda(alvo.valor)}',
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
                labelText: 'Novo valor',
                prefixText: r'R$ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            if (podeRedistribuir)
              SegmentedButton<ModoCompensacao>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ModoCompensacao.redistribuir,
                    label: Text('Redistribuir'),
                  ),
                  ButtonSegment(
                    value: ModoCompensacao.ajustarSomente,
                    label: Text('Só esta parcela'),
                  ),
                ],
                selected: {_modo},
                onSelectionChanged: (s) => setState(() => _modo = s.first),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(switch (modo) {
              ModoCompensacao.redistribuir =>
                'A diferença é dividida entre as demais parcelas '
                    'pendentes e o total da venda não muda.',
              ModoCompensacao.ajustarSomente when !podeRedistribuir =>
                'Não há outras parcelas pendentes: só esta parcela muda '
                    'e o total da venda muda junto.',
              ModoCompensacao.ajustarSomente =>
                'Só esta parcela muda e o total da venda muda junto.',
            }, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _motivo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            if (erro != null)
              Text(
                erro,
                style: AppTextStyles.body.copyWith(color: AppColors.scoreD),
              )
            else if (resultado != null)
              _Previa(antes: parcelas, resultado: resultado),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              texto: 'Confirmar alteração',
              carregando: salvando,
              onPressed: resultado != null && resultado.ok
                  ? () => _confirmar(parcelas, resultado)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Como ficam as parcelas antes de confirmar.
class _Previa extends StatelessWidget {
  const _Previa({required this.antes, required this.resultado});

  final List<ParcelaModel> antes;
  final ResultadoAlteracaoParcela resultado;

  @override
  Widget build(BuildContext context) {
    final alteradas = {for (final a in resultado.alteradas) a.parcelaId};
    final valorAntes = {for (final p in antes) p.id: p.valor};
    final totalMuda = resultado.diferencaTotal != 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Prévia', style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            for (final p in resultado.parcelasResultantes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.numero}ª · ${formatarData(p.vencimento)}'
                        '${p.pago ? ' · paga' : ''}',
                        style: AppTextStyles.cardSubtitle,
                      ),
                    ),
                    if (alteradas.contains(p.id)) ...[
                      Text(
                        formatarMoeda(valorAntes[p.id] ?? 0),
                        style: AppTextStyles.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      formatarMoeda(p.valor),
                      style: alteradas.contains(p.id)
                          ? AppTextStyles.money.copyWith(
                              color: AppColors.primaryDark,
                            )
                          : AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            const Divider(color: AppColors.border),
            Row(
              children: [
                const Expanded(
                  child: Text('Total da venda', style: AppTextStyles.body),
                ),
                if (totalMuda) ...[
                  Text(
                    formatarMoeda(resultado.totalAnterior),
                    style: AppTextStyles.caption.copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  formatarMoeda(resultado.totalNovo),
                  style: AppTextStyles.money,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
