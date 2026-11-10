import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/navigation/app_routes.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../domain/rotulos_venda.dart';
import '../domain/troca.dart';
import 'alterar_valor_parcela_sheet.dart';
import 'comprovante_providers.dart';
import 'observacao_dialog.dart';
import 'pos_venda_providers.dart';
import 'registrar_pagamento_sheet.dart';
import 'troca_sheet.dart';

/// Detalhes de uma venda registrada: itens, pagamento, parcelas, trocas
/// (KAN-28) e observações pós-venda (KAN-29).
///
/// Recebe o id da venda como argumento da rota.
class DetalhesVendaScreen extends ConsumerWidget {
  const DetalhesVendaScreen({required this.vendaId, super.key});

  final String vendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venda = ref.watch(vendaPorIdProvider(vendaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Venda'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: venda.when(
        data: (v) => v == null
            ? const Center(
                child: EmptyState(
                  icone: Icons.receipt_long_outlined,
                  titulo: 'Venda não encontrada',
                  descricao: 'Ela pode ter sido removida.',
                ),
              )
            : _Detalhes(venda: v),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar venda $vendaId: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar venda',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.venda});

  final VendaModel venda;

  @override
  Widget build(BuildContext context) {
    final pagamento = venda.formaPagamento?.rotulo ?? venda.tipo.rotulo;
    final podeTrocar = venda.itens.any((i) => quantidadeTrocavel(venda, i) > 0);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Nota ${venda.numeroNota}', style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${venda.clienteNome} · ${formatarData(venda.data)}',
          style: AppTextStyles.cardSubtitle,
        ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeader(titulo: 'Itens'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final item in venda.itens)
                  _Linha(
                    titulo: '${item.quantidade}x ${item.nome}',
                    detalhe: '${formatarMoeda(item.precoUnitario)} cada',
                    valor: formatarMoeda(item.subtotal),
                  ),
                const Divider(color: AppColors.border),
                _Linha(
                  titulo: 'Total',
                  detalhe: pagamento,
                  valor: formatarMoeda(venda.valorTotal),
                  destaque: true,
                ),
              ],
            ),
          ),
        ),

        if (venda.ehPromissoria) ...[
          const SizedBox(height: AppSpacing.lg),
          _Parcelas(venda: venda),
        ],

        if (venda.trocas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(titulo: 'Trocas'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  for (final troca in venda.trocas)
                    _Linha(
                      titulo:
                          '${troca.quantidade}x ${_nomeOriginal(troca)} → '
                          '${troca.produtoNovoNome}',
                      detalhe: formatarData(troca.data),
                      valor: troca.diferencaValor == 0
                          ? '—'
                          : formatarMoeda(troca.diferencaValor),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          titulo: 'Observações',
          acao: TextButton(
            onPressed: () => editarObservacao(context, venda),
            child: Text(
              (venda.observacao?.isEmpty ?? true) ? 'Adicionar' : 'Editar',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              (venda.observacao?.isEmpty ?? true)
                  ? 'Nenhuma observação.'
                  : venda.observacao!,
              style: AppTextStyles.body,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          texto: 'Nota provisória',
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(AppRoutes.notaProvisoria, arguments: venda.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          texto: 'Registrar troca',
          onPressed: podeTrocar ? () => registrarTroca(context, venda) : null,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  String _nomeOriginal(TrocaItem troca) {
    for (final item in venda.itens) {
      if (item.id == troca.itemOriginalId) return item.nome;
    }
    return 'Produto';
  }
}

class _Parcelas extends ConsumerWidget {
  const _Parcelas({required this.venda});

  final VendaModel venda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelas = ref.watch(parcelasDaVendaProvider(venda.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(titulo: 'Parcelas'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: parcelas.when(
              data: (lista) => Column(
                children: [
                  for (final p in lista)
                    _LinhaParcela(venda: venda, parcela: p),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                debugPrint('Erro ao carregar parcelas: $error');
                return const Text(
                  'Erro ao carregar parcelas.',
                  style: AppTextStyles.body,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LinhaParcela extends StatelessWidget {
  const _LinhaParcela({required this.venda, required this.parcela});

  final VendaModel venda;
  final ParcelaModel parcela;

  String? get _aviso {
    final p = parcela;
    if (p.pago) return 'Parcela paga não pode ser alterada';
    final partes = [
      if (p.totalPago > 0 && !p.pago) 'Saldo ${formatarMoeda(p.saldo)}',
      if (p.alteracoes.isNotEmpty)
        'Valor alterado (era ${formatarMoeda(p.alteracoes.first.valorAnterior)})',
    ];
    return partes.isEmpty ? null : partes.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final p = parcela;
    final aviso = _aviso;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.numero}ª · ${formatarData(p.vencimento)}',
                  style: AppTextStyles.body,
                ),
              ),
              if (p.pago)
                const StatusBadge.emDia()
              else if (p.atrasada)
                const StatusBadge.vencido(),
              const SizedBox(width: AppSpacing.sm),
              Text(formatarMoeda(p.valor), style: AppTextStyles.money),
            ],
          ),
          if (aviso != null) Text(aviso, style: AppTextStyles.caption),
          // Pagamentos registrados, cada um com o seu comprovante (KAN-36).
          for (final g in p.pagamentos)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pago ${formatarMoeda(g.valor)} · ${formatarData(g.data)} '
                    '· ${g.forma.rotulo}',
                    style: AppTextStyles.caption,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.comprovante,
                    arguments: ComprovanteArgs(
                      vendaId: venda.id,
                      parcelaId: p.id,
                      pagamentoId: g.id,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Comprovante'),
                ),
              ],
            ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: p.pago
                    ? null
                    : () => registrarPagamentoSheet(
                        context,
                        venda: venda,
                        parcela: p,
                      ),
                child: const Text('Registrar pagamento'),
              ),
              TextButton(
                onPressed: p.pago
                    ? null
                    : () => alterarValorParcelaSheet(
                        context,
                        venda: venda,
                        parcela: p,
                      ),
                child: const Text('Alterar valor'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.titulo,
    required this.detalhe,
    required this.valor,
    this.destaque = false,
  });

  final String titulo;
  final String detalhe;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.cardTitle),
                Text(detalhe, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            valor,
            style: destaque ? AppTextStyles.money : AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
