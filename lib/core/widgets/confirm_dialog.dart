import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Pede confirmação antes de uma ação sensível (KAN-20). Retorna `true`
/// só se o usuário tocar em [textoConfirmar]; cancelar ou fechar o
/// dialog retorna `false`.
///
/// [destrutiva] pinta o botão de confirmação de vermelho, para ações que
/// restringem algo (ex. bloquear um cliente).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String textoConfirmar,
  bool destrutiva = false,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(titulo, style: AppTextStyles.sectionTitle),
      content: Text(mensagem, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: destrutiva
              ? TextButton.styleFrom(foregroundColor: AppColors.scoreD)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
