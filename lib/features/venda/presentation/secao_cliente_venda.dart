import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/score_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/pendencia_cliente.dart';
import 'nova_venda_providers.dart';

/// Seleção do cliente com alerta de pendência (KAN-24).
class SecaoClienteVenda extends StatelessWidget {
  const SecaoClienteVenda({
    required this.venda,
    required this.onEscolher,
    super.key,
  });

  final NovaVendaState venda;
  final VoidCallback onEscolher;

  @override
  Widget build(BuildContext context) {
    final cliente = venda.cliente;
    final pendencia = venda.pendencia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(titulo: 'Cliente'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: InkWell(
            onTap: onEscolher,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: cliente == null
                  ? const Row(
                      children: [
                        Icon(Icons.person_search, color: AppColors.primary),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Toque para buscar o cliente',
                            style: AppTextStyles.body,
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cliente.nome,
                                style: AppTextStyles.cardTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'CPF ${cliente.cpf}',
                                style: AppTextStyles.cardSubtitle,
                              ),
                            ],
                          ),
                        ),
                        ScoreBadge(cliente.score),
                        const SizedBox(width: AppSpacing.sm),
                        const Text(
                          'Trocar',
                          style: TextStyle(color: AppColors.primaryDark),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (pendencia != null && pendencia.temPendencia) ...[
          const SizedBox(height: AppSpacing.sm),
          _AlertaPendencia(pendencia: pendencia),
        ],
      ],
    );
  }
}

class _AlertaPendencia extends StatelessWidget {
  const _AlertaPendencia({required this.pendencia});

  final PendenciaCliente pendencia;

  @override
  Widget build(BuildContext context) {
    final cor = pendencia.nivel == NivelPendencia.bloqueado
        ? AppColors.statusBloqueado
        : AppColors.statusInadimplente;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final mensagem in pendencia.mensagens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      mensagem,
                      style: AppTextStyles.body.copyWith(color: cor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
