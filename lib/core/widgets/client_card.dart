import 'package:flutter/material.dart';

import '../../features/cliente/data/cliente_model.dart';
import '../../features/cliente/domain/status_pagamento.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'score_badge.dart';
import 'status_badge.dart';

/// Card de cliente usado nas listas de agenda e cadastro.
///
/// O status de pagamento exibido vem de [statusPagamento] (KAN-16) — o
/// card só mostra o badge correspondente, sem calcular nada.
class ClientCard extends StatelessWidget {
  const ClientCard({required this.cliente, this.onTap, super.key});

  final ClienteModel cliente;
  final VoidCallback? onTap;

  static const double _avatarRaio = 22;

  @override
  Widget build(BuildContext context) {
    final inicial = cliente.nome.isEmpty ? '?' : cliente.nome[0].toUpperCase();
    final corAvatarTexto = AppColors.textoContrastante(AppColors.primary);

    final statusBadge = StatusBadge.pagamento(statusPagamento(cliente));

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: _avatarRaio,
                backgroundColor: AppColors.primary,
                child: Text(
                  inicial,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: corAvatarTexto,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente.nome, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(cliente.endereco, style: AppTextStyles.cardSubtitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ScoreBadge(cliente.score),
                  const SizedBox(height: AppSpacing.xs),
                  statusBadge,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
