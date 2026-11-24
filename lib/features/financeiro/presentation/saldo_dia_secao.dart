import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/resumo_dia.dart';
import 'saldo_dia_providers.dart';

/// Saldo do dia (RF29, KAN-51): vendas, despesas e saldo do vendedor no
/// dia escolhido no seletor de dia, seguindo o painel do protótipo.
class SaldoDiaSecao extends ConsumerWidget {
  const SaldoDiaSecao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoDoDiaProvider);

    return resumo.when(
      skipLoadingOnReload: true,
      data: (r) => _Resumo(resumo: r),
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        debugPrint('Erro ao calcular o saldo do dia: $error');
        return const EmptyState(
          icone: Icons.error_outline,
          titulo: 'Erro ao calcular o saldo',
          descricao: 'Verifique a conexão e tente novamente.',
        );
      },
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.resumo});

  final ResumoDia resumo;

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardVendas(resumo: r),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _CardDespesas(resumo: r)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _CardSaldo(saldo: r.saldo)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Detalhamento(resumo: r),
        if (r.itensSemCusto > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            r.itensSemCusto == 1
                ? '1 item vendido está sem custo cadastrado, então o '
                      'lucro e o saldo aparecem maiores que o real.'
                : '${r.itensSemCusto} itens vendidos estão sem custo '
                      'cadastrado, então o lucro e o saldo aparecem '
                      'maiores que o real.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusAtencao,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardVendas extends StatelessWidget {
  const _CardVendas({required this.resumo});

  final ResumoDia resumo;

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    final pedidos = r.pedidos == 1 ? '1 venda' : '${r.pedidos} vendas';
    final unidades = r.unidades == 1 ? '1 item' : '${r.unidades} itens';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Rotulo(icone: Icons.trending_up, texto: 'VENDAS DO DIA'),
            const SizedBox(height: AppSpacing.sm),
            Text(formatarMoeda(r.faturamento), style: AppTextStyles.moneyLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('$pedidos · $unidades', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _CardDespesas extends StatelessWidget {
  const _CardDespesas({required this.resumo});

  final ResumoDia resumo;

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.despesas),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Rotulo(icone: Icons.trending_down, texto: 'DESPESAS'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatarMoeda(r.despesas),
                style: AppTextStyles.money.copyWith(
                  color: AppColors.statusInadimplente,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                r.quantidadeDespesas == 1
                    ? '1 lançamento'
                    : '${r.quantidadeDespesas} lançamentos',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSaldo extends StatelessWidget {
  const _CardSaldo({required this.saldo});

  final double saldo;

  @override
  Widget build(BuildContext context) {
    const fundo = AppColors.primaryDark;
    final texto = AppColors.textoContrastante(fundo);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rotulo(
            icone: Icons.account_balance_wallet_outlined,
            texto: 'SALDO DO DIA',
            cor: texto,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatarMoeda(saldo),
            style: AppTextStyles.money.copyWith(color: texto),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            saldo < 0 ? 'Despesas maiores que o lucro' : 'Lucro − despesas',
            style: AppTextStyles.caption.copyWith(color: texto),
          ),
        ],
      ),
    );
  }
}

/// Conta do saldo, linha a linha, para o vendedor conferir.
class _Detalhamento extends StatelessWidget {
  const _Detalhamento({required this.resumo});

  final ResumoDia resumo;

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _Linha('Vendas', formatarMoeda(r.faturamento)),
            _Linha(
              'Custo dos produtos',
              '− ${formatarMoeda(r.custoProdutos)}',
            ),
            const Divider(color: AppColors.border),
            _Linha('Lucro bruto', formatarMoeda(r.lucroBruto)),
            _Linha('Despesas', '− ${formatarMoeda(r.despesas)}'),
            const Divider(color: AppColors.border),
            _Linha('Saldo do dia', formatarMoeda(r.saldo), destaque: true),
          ],
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor, {this.destaque = false});

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final estilo = destaque ? AppTextStyles.money : AppTextStyles.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.icone, required this.texto, this.cor});

  final IconData icone;
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? AppColors.textSecondary;
    return Row(
      children: [
        Icon(icone, size: AppSpacing.md, color: c),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            texto,
            style: AppTextStyles.badge.copyWith(color: c),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}