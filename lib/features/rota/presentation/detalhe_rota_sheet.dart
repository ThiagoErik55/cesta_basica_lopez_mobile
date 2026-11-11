import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/cadastro_rota.dart';
import 'rota_form_sheet.dart';
import 'rota_providers.dart';

/// Abre o detalhe da rota: dados, quantidade e nomes dos clientes
/// associados (somente leitura).
///
/// [aoAssociarClientes] é o ponto de extensão da KAN-46: ela liga o botão
/// "Associar clientes". Sem ele, o botão aparece desabilitado.
Future<void> mostrarDetalheRota(
  BuildContext context,
  String rotaId, {
  VoidCallback? aoAssociarClientes,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      DetalheRotaSheet(rotaId: rotaId, aoAssociarClientes: aoAssociarClientes),
);

class DetalheRotaSheet extends ConsumerWidget {
  const DetalheRotaSheet({
    required this.rotaId,
    this.aoAssociarClientes,
    super.key,
  });

  final String rotaId;

  /// KAN-46 liga este callback; até lá o botão fica desabilitado.
  final VoidCallback? aoAssociarClientes;

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    ItemRota item,
  ) async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);

    final bloqueio = motivoBloqueioExclusaoRota(item.clientes);
    if (bloqueio != null) {
      mensageiro.showSnackBar(SnackBar(content: Text(bloqueio)));
      return;
    }
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir rota',
      mensagem: 'Excluir a rota "${item.rota.nome}"? Ela some da lista.',
      textoConfirmar: 'Excluir',
      destrutiva: true,
    );
    if (!confirmado || !context.mounted) return;

    try {
      final sincronizado = await ref
          .read(salvarRotaProvider.notifier)
          .excluir(item.rota.id);
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Rota excluída.'
                : 'Rota excluída. Será sincronizado quando houver conexão.',
          ),
        ),
      );
    } on StateError catch (e) {
      // Um cliente foi associado enquanto o diálogo estava aberto.
      mensageiro.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Erro ao excluir rota: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível excluir a rota. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Em tempo real: renomear ou associar cliente com o detalhe aberto
    // atualiza esta tela.
    final item = ref
        .watch(itensRotaProvider)
        .value
        ?.where((i) => i.rota.id == rotaId)
        .firstOrNull;

    if (item == null) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: EmptyState(
            icone: Icons.route_outlined,
            titulo: 'Rota não encontrada',
            descricao: 'Ela pode ter sido excluída.',
          ),
        ),
      );
    }

    final rota = item.rota;
    final clientes = ref.watch(clientesDasRotasProvider);
    // Observado para o provider (autoDispose) continuar vivo durante a
    // exclusão, e para bloquear toques repetidos enquanto grava.
    final salvando = ref.watch(salvarRotaProvider).isLoading;
    final bloqueio = motivoBloqueioExclusaoRota(item.clientes);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(rota.nome, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${rota.linhaAtendimento.rotulo} · ${rota.codigo}',
            style: AppTextStyles.cardSubtitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            textoClientesDaRota(item.clientes) ?? 'Clientes: indisponível',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => mostrarFormularioRota(context, rota: rota),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.scoreD,
                  ),
                  onPressed: salvando
                      ? null
                      : () => _excluir(context, ref, item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ),
            ],
          ),
          if (bloqueio != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(bloqueio, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          // KAN-46 liga este botão pelo callback [aoAssociarClientes].
          OutlinedButton.icon(
            onPressed: aoAssociarClientes,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Associar clientes'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Clientes da rota'),
          const SizedBox(height: AppSpacing.sm),
          clientes.when(
            data: (lista) {
              final nomes = nomesDosClientesDaRota(rota.id, lista);
              if (nomes.isEmpty) {
                return const EmptyState(
                  icone: Icons.people_outline,
                  titulo: 'Nenhum cliente nesta rota',
                  descricao: 'Os clientes associados aparecem aqui.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final nome in nomes)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(nome, style: AppTextStyles.body),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Text('Não foi possível carregar os clientes desta rota.'),
          ),
        ],
      ),
    );
  }
}
