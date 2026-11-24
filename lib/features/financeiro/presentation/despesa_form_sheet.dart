import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/despesa_model.dart';
import '../domain/dia.dart';
import '../domain/formulario_despesa.dart';
import 'despesa_providers.dart';

/// Abre o lançamento de despesa (KAN-50). Com [despesa], edita a
/// existente; sem ela, cria uma nova no [dia] informado.
Future<void> abrirFormularioDespesa(
  BuildContext context, {
  DespesaModel? despesa,
  required DateTime dia,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DespesaFormSheet(despesa: despesa, dia: dia),
);

class DespesaFormSheet extends ConsumerStatefulWidget {
  const DespesaFormSheet({this.despesa, required this.dia, super.key});

  final DespesaModel? despesa;
  final DateTime dia;

  @override
  ConsumerState<DespesaFormSheet> createState() => _DespesaFormSheetState();
}

class _DespesaFormSheetState extends ConsumerState<DespesaFormSheet> {
  late final _descricao = TextEditingController(
    text: widget.despesa?.descricao,
  );
  late final _valor = TextEditingController(
    text: widget.despesa == null
        ? ''
        : formatarValorEditavel(widget.despesa!.valor),
  );
  late DateTime _data = inicioDoDia(widget.despesa?.data ?? widget.dia);
  bool _tentou = false;

  bool get _editando => widget.despesa != null;

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = inicioDoDia(DateTime.now());
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data.isAfter(hoje) ? hoje : _data,
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: hoje,
      helpText: 'Data da despesa',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar(ResultadoDespesa r) async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(salvarDespesaProvider.notifier)
          .salvar(
            existente: widget.despesa,
            descricao: r.descricao,
            valor: r.valor!,
            data: _data,
          );
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            '${_editando ? 'Despesa atualizada.' : 'Despesa registrada.'}'
            '${sincronizado ? '' : ' Salva no aparelho: será enviada quando houver conexão.'}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar despesa: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a despesa. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salvando = ref.watch(salvarDespesaProvider).isLoading;
    final r = avaliarDespesa(
      descricao: _descricao.text,
      valor: lerValorMonetario(_valor.text),
      data: _data,
      agora: DateTime.now(),
    );

    // Erros só aparecem depois de o campo ser preenchido ou da primeira
    // tentativa de salvar, para o formulário não abrir "vermelho".
    String? erro(String? mensagem, TextEditingController c) =>
        _tentou || c.text.isNotEmpty ? mensagem : null;

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
              _editando ? 'Editar despesa' : 'Nova despesa',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final sugestao in sugestoesDespesa)
                  ActionChip(
                    label: Text(sugestao),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => setState(() {
                      _descricao.text = sugestao;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descricao,
              maxLength: limiteDescricaoDespesa,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex.: Combustível',
                errorText: erro(r.erroDescricao, _descricao),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [valorMonetarioFormatter],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Valor',
                prefixText: r'R$ ',
                errorText: erro(r.erroValor, _valor),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Text('Data', style: AppTextStyles.body),
                ),
                TextButton.icon(
                  onPressed: salvando ? null : _escolherData,
                  icon: const Icon(Icons.event),
                  label: Text(formatarData(_data)),
                ),
              ],
            ),
            if (r.erroData case final e?)
              Text(
                e,
                style: AppTextStyles.caption.copyWith(color: AppColors.scoreD),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              texto: _editando ? 'Salvar alterações' : 'Registrar despesa',
              carregando: salvando,
              onPressed: () {
                if (!r.ok) {
                  setState(() => _tentou = true);
                  return;
                }
                _salvar(r);
              },
            ),
          ],
        ),
      ),
    );
  }
}