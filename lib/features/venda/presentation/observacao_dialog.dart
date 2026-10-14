import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/venda_model.dart';
import 'pos_venda_providers.dart';

/// Edição da observação pós-venda (RF26, KAN-29).
Future<void> editarObservacao(BuildContext context, VendaModel venda) =>
    showDialog(
      context: context,
      builder: (_) => _ObservacaoDialog(venda: venda),
    );

class _ObservacaoDialog extends ConsumerStatefulWidget {
  const _ObservacaoDialog({required this.venda});

  final VendaModel venda;

  @override
  ConsumerState<_ObservacaoDialog> createState() => _ObservacaoDialogState();
}

class _ObservacaoDialogState extends ConsumerState<_ObservacaoDialog> {
  static const _limite = 500;

  late final _texto = TextEditingController(text: widget.venda.observacao);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(posVendaProvider.notifier)
          .salvarObservacao(widget.venda.id, _texto.text);
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Observação salva.'
                : 'Observação salva no aparelho. Será enviada quando '
                      'houver conexão.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar observação: $e');
      mensageiro.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar. Tente de novo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salvando = ref.watch(posVendaProvider).isLoading;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Observação', style: AppTextStyles.sectionTitle),
      content: TextField(
        controller: _texto,
        autofocus: true,
        maxLines: 6,
        minLines: 3,
        maxLength: _limite,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ex.: cliente pediu entrega na próxima visita',
        ),
      ),
      actions: [
        TextButton(
          onPressed: salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: salvando ? null : _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
