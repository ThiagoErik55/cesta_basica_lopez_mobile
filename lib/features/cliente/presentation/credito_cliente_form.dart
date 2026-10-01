import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/cliente_model.dart';
import 'cliente_providers.dart';

/// Edição manual de score, limite de crédito e bloqueio (KAN-20), na
/// tela de detalhes. Separada de propósito do formulário cadastral
/// (ClienteForm): são decisões de crédito, não dados do cliente.
///
/// Esses valores são definidos à mão até existirem (a) o histórico de
/// vendas e parcelas para o cálculo automático do score (Sprint 4) e
/// (b) a definição da empresa sobre a regra de bloqueio automático por
/// atraso (RF30, pendência do modelo lógico). Quando existirem, esta
/// seção deve virar só uma exceção manual ao valor calculado.
///
/// Use uma key que mude quando o cliente for recarregado (ex.
/// `updatedAt`), para os campos voltarem aos valores salvos.
class CreditoClienteForm extends ConsumerStatefulWidget {
  const CreditoClienteForm({required this.cliente, super.key});

  final ClienteModel cliente;

  @override
  ConsumerState<CreditoClienteForm> createState() => _CreditoClienteFormState();
}

class _CreditoClienteFormState extends ConsumerState<CreditoClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late ScoreCliente _score = widget.cliente.score;
  late bool _bloqueado = widget.cliente.bloqueado;
  late final _limite = TextEditingController(
    text: formatarValorEditavel(widget.cliente.limiteCredito),
  );

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  bool get _alterado =>
      _score != widget.cliente.score ||
      _bloqueado != widget.cliente.bloqueado ||
      lerValorMonetario(_limite.text) != widget.cliente.limiteCredito;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Bloquear impede o cliente de comprar — pede confirmação. Desbloquear
    // não, porque só devolve o acesso.
    if (_bloqueado && !widget.cliente.bloqueado) {
      final confirmado = await confirmar(
        context,
        titulo: 'Bloquear ${widget.cliente.nome}?',
        mensagem:
            'Um cliente bloqueado não pode fazer novas compras até ser '
            'desbloqueado.',
        textoConfirmar: 'Bloquear',
        destrutiva: true,
      );
      if (!confirmado || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(salvarClienteProvider.notifier)
          .atualizarCredito(
            widget.cliente,
            score: _score,
            limiteCredito: lerValorMonetario(_limite.text)!,
            bloqueado: _bloqueado,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Crédito atualizado.'
                : 'Crédito atualizado. Será sincronizado quando houver '
                      'conexão.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o crédito. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar mantém o notifier (autoDispose) vivo durante o salvamento.
    final salvando = ref.watch(salvarClienteProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('Score', style: AppTextStyles.cardSubtitle),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilterChipBar<ScoreCliente>(
                opcoes: [
                  for (final score in ScoreCliente.values)
                    OpcaoFiltro(score.name.toUpperCase(), score),
                ],
                selecionado: _score,
                onSelecionar: (score) {
                  if (score != null) setState(() => _score = score);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextFormField(
                  controller: _limite,
                  decoration: const InputDecoration(
                    labelText: 'Limite de crédito',
                    prefixText: r'R$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [valorMonetarioFormatter],
                  validator: (v) {
                    final valor = lerValorMonetario(v ?? '');
                    if (valor == null) return 'Informe o limite.';
                    if (valor < 0) return 'O limite não pode ser negativo.';
                    return null;
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                title: const Text('Bloqueado', style: AppTextStyles.body),
                subtitle: const Text(
                  'Impede novas compras do cliente.',
                  style: AppTextStyles.caption,
                ),
                activeTrackColor: AppColors.statusBloqueado,
                value: _bloqueado,
                onChanged: (valor) => setState(() => _bloqueado = valor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: PrimaryButton(
                  texto: 'Salvar crédito',
                  carregando: salvando,
                  onPressed: _alterado ? _salvar : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
