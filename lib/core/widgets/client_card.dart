import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cliente/data/cliente_model.dart';
import '../../features/cliente/domain/bloqueio_cliente.dart';
import '../providers/regra_bloqueio_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'score_badge.dart';
import 'status_badge.dart';

/// Card de cliente usado nas listas de agenda e cadastro.
///
/// O status exibido vem de [situacaoDoClientePeloResumo] (KAN-16,
/// KAN-35): já considera o bloqueio automático por atraso ou limite, com
/// o motivo. O card só mostra o badge correspondente.
class ClientCard extends ConsumerWidget {
  const ClientCard({
    required this.cliente,
    this.onTap,
    this.rotaNome,
    this.detalhes = const [],
    this.rodape,
    this.situacao,
    super.key,
  });

  final ClienteModel cliente;
  final VoidCallback? onTap;

  /// Nome da rota ativa do cliente (KAN-46), em texto pequeno abaixo do
  /// endereço. `null` (sem rota, rota excluída ou ainda carregando) não
  /// mostra nada.
  final String? rotaNome;

  /// Linhas extras abaixo do endereço e da rota (ex. valores e destaques
  /// da agenda, KAN-47).
  final List<Widget> detalhes;

  /// Faixa abaixo do cartão, dentro dele (ex. ações rápidas da agenda).
  final Widget? rodape;

  /// Situação já calculada por quem tem as parcelas (a agenda). Sem ela, o
  /// card usa o resumo do próprio cliente.
  final SituacaoCliente? situacao;

  static const double _avatarRaio = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inicial = cliente.nome.isEmpty ? '?' : cliente.nome[0].toUpperCase();
    final corAvatarTexto = AppColors.textoContrastante(AppColors.primary);

    final situacaoExibida =
        situacao ??
        situacaoDoClientePeloResumo(
          cliente,
          regra: ref.watch(regraBloqueioProvider),
        );
    final statusBadge = StatusBadge.pagamento(situacaoExibida.status);
    final motivo = situacaoExibida.motivo;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                        Text(
                          cliente.endereco,
                          style: AppTextStyles.cardSubtitle,
                        ),
                        if (rotaNome != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Rota: $rotaNome',
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        ...detalhes,
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
                      if (motivo != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(motivo, style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ],
              ),
              ?rodape,
            ],
          ),
        ),
      ),
    );
  }
}
