import 'package:flutter/material.dart';

import '../../features/cliente/domain/status_pagamento.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Badge textual de status financeiro do cliente.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.texto, this.cor, {super.key});

  const StatusBadge.emDia({super.key})
    : texto = 'Em dia',
      cor = AppColors.statusEmDia;

  const StatusBadge.atencao({super.key})
    : texto = 'Atenção',
      cor = AppColors.statusAtencao;

  const StatusBadge.inadimplente({super.key})
    : texto = 'Inadimplente',
      cor = AppColors.statusInadimplente;

  const StatusBadge.vencido({super.key})
    : texto = 'Vencido',
      cor = AppColors.statusVencido;

  const StatusBadge.emAtraso({super.key})
    : texto = 'Em atraso',
      cor = AppColors.statusVencido;

  const StatusBadge.bloqueado({super.key})
    : texto = 'Bloqueado',
      cor = AppColors.statusBloqueado;

  /// Badge do status de pagamento do cliente (KAN-16), o mesmo no card
  /// da listagem e na tela de detalhes.
  factory StatusBadge.pagamento(StatusPagamento status, {Key? key}) =>
      switch (status) {
        StatusPagamento.emDia => StatusBadge.emDia(key: key),
        StatusPagamento.emAtraso => StatusBadge.emAtraso(key: key),
        StatusPagamento.bloqueado => StatusBadge.bloqueado(key: key),
      };

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final corTexto = AppColors.textoContrastante(cor);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        texto.toUpperCase(),
        style: AppTextStyles.badge.copyWith(color: corTexto),
      ),
    );
  }
}
