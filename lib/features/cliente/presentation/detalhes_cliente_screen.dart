import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/score_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/cliente_model.dart';
import '../domain/status_pagamento.dart';
import 'cliente_providers.dart';
import 'credito_cliente_form.dart';
import 'historico_cliente_secoes.dart';

/// Detalhes do cliente (KAN-17): dados cadastrais, status de pagamento e
/// situação financeira (somente leitura). Os dados cadastrais são
/// editados pelo botão da AppBar; score, limite e bloqueio, na seção
/// Crédito (KAN-20). Os históricos de compras e pagamentos (KAN-18,
/// KAN-19) vêm das vendas e parcelas reais (KAN-33).
///
/// Recebe o id do cliente como argumento da rota.
class DetalhesClienteScreen extends ConsumerWidget {
  const DetalhesClienteScreen({required this.clienteId, super.key});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(clientePorIdProvider(clienteId));
    final carregado = cliente.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        actions: [
          if (carregado != null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .pushNamed(AppRoutes.editarCliente, arguments: carregado),
            ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: cliente.when(
        data: (c) => c == null
            ? const Center(
                child: EmptyState(
                  icone: Icons.person_off_outlined,
                  titulo: 'Cliente não encontrado',
                  descricao: 'Ele pode ter sido removido.',
                ),
              )
            : _Detalhes(cliente: c),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          debugPrint('Erro ao carregar cliente $clienteId: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar cliente',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.cliente});

  final ClienteModel cliente;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(cliente.nome, style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text('Código ${cliente.codigo}', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            ScoreBadge(cliente.score),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge.pagamento(statusPagamento(cliente)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(titulo: 'Dados cadastrais'),
        const SizedBox(height: AppSpacing.sm),
        _CardInformacoes(
          linhas: [
            ('CPF', cliente.cpf),
            ('Telefone', cliente.telefone),
            ('Endereço', cliente.endereco),
            // rotaId ainda é texto livre (não há cadastro de rotas).
            ('Rota', cliente.rotaId ?? 'Sem rota'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Derivados das vendas e parcelas — só leitura.
        const SectionHeader(titulo: 'Situação financeira'),
        const SizedBox(height: AppSpacing.sm),
        _CardInformacoes(
          linhas: [
            ('Valor em aberto', formatarMoeda(cliente.valorEmAberto)),
            ('Próximo vencimento', formatarData(cliente.proximoVencimento)),
            (
              'Última compra',
              formatarData(cliente.ultimaCompra, vazio: 'Nenhuma'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        SecondaryButton(
          texto: 'Ver promissórias',
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(AppRoutes.promissorias, arguments: cliente.id),
        ),
        const SizedBox(height: AppSpacing.lg),

        HistoricoComprasSecao(clienteId: cliente.id),
        const SizedBox(height: AppSpacing.lg),
        HistoricoPagamentosSecao(clienteId: cliente.id),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(titulo: 'Crédito'),
        const SizedBox(height: AppSpacing.sm),
        // A key recria o formulário quando o cliente é recarregado após
        // salvar, para os campos refletirem os valores gravados.
        CreditoClienteForm(key: ValueKey(cliente.updatedAt), cliente: cliente),
      ],
    );
  }
}

/// Card com pares rótulo/valor, um por linha.
class _CardInformacoes extends StatelessWidget {
  const _CardInformacoes({required this.linhas});

  final List<(String, String)> linhas;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            for (final (i, (rotulo, valor)) in linhas.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(rotulo, style: AppTextStyles.cardSubtitle),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: Text(
                      valor,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
