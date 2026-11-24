import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/agregacao_financeira.dart';
import 'painel_providers.dart';

/// Cartões do topo do painel (KAN-52).
class PainelIndicadores extends StatelessWidget {
  const PainelIndicadores({
    required this.painel,
    required this.recebiveis,
    super.key,
  });

  final PainelFinanceiro painel;

  /// `null` enquanto as promissórias não carregaram (ou se falharam).
  final PosicaoRecebiveis? recebiveis;

  @override
  Widget build(BuildContext context) {
    final t = painel.totais;
    final c = painel.comparacao;
    final recebido = painel.recebidoCompleto
        ? formatarCentavos(t.recebido)
        : '—';
    final linhas = <List<Widget>>[
      [
        CartaoIndicador(
          rotulo: 'FATURAMENTO',
          valor: formatarCentavos(t.faturamento),
          comparar: true,
          variacao: c.variacaoFaturamento,
        ),
        CartaoIndicador(
          rotulo: 'CUSTO DOS PRODUTOS',
          valor: formatarCentavos(t.custo),
        ),
      ],
      [
        CartaoIndicador(
          rotulo: 'LUCRO BRUTO',
          valor: formatarCentavos(t.lucroBruto),
        ),
        CartaoIndicador(
          rotulo: 'DESPESAS',
          valor: formatarCentavos(t.despesas),
          comparar: true,
          variacao: c.variacaoDespesas,
          altaEhRuim: true,
        ),
      ],
      [
        CartaoIndicador(
          rotulo: 'LUCRO LÍQUIDO',
          valor: formatarCentavos(t.lucroLiquido),
          comparar: true,
          variacao: c.variacaoLucroLiquido,
          destaque: true,
        ),
        CartaoIndicador(
          rotulo: 'VENDAS',
          valor: '${t.vendas}',
          detalhe: t.unidades == 1 ? '1 item' : '${t.unidades} itens',
        ),
      ],
      [
        CartaoIndicador(
          rotulo: 'TICKET MÉDIO',
          valor: formatarCentavos(t.ticketMedio),
        ),
        CartaoIndicador(
          rotulo: 'RECEBIDO NO PERÍODO',
          valor: recebido,
          detalhe: 'À vista e parcelas, fora do lucro',
        ),
      ],
      [
        CartaoIndicador(
          rotulo: 'A RECEBER',
          valor: recebiveis == null
              ? '—'
              : formatarCentavos(recebiveis!.aReceber),
          detalhe: 'Em aberto hoje',
        ),
        CartaoIndicador(
          rotulo: 'EM ATRASO',
          valor: recebiveis == null
              ? '—'
              : formatarCentavos(recebiveis!.emAtraso),
          detalhe: 'Vencido hoje',
          cor: (recebiveis?.emAtraso ?? 0) > 0
              ? AppColors.statusInadimplente
              : null,
        ),
      ],
    ];

    return Column(
      children: [
        for (final (i, linha) in linhas.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: linha[0]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: linha[1]),
              ],
            ),
          ),
        ],
        if (t.itensSemCusto > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            t.itensSemCusto == 1
                ? '1 item vendido está sem custo cadastrado: o lucro '
                      'aparece maior que o real.'
                : '${t.itensSemCusto} itens vendidos estão sem custo '
                      'cadastrado: o lucro aparece maior que o real.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.statusAtencao,
            ),
          ),
        ],
      ],
    );
  }
}

/// Um indicador do painel. Com [variacao], mostra a comparação com o
/// período anterior; [altaEhRuim] inverte as cores (despesas).
class CartaoIndicador extends StatelessWidget {
  const CartaoIndicador({
    required this.rotulo,
    required this.valor,
    this.detalhe,
    this.variacao,
    this.comparar = false,
    this.altaEhRuim = false,
    this.destaque = false,
    this.cor,
    super.key,
  });

  final String rotulo;
  final String valor;
  final String? detalhe;

  /// Variação percentual; `null` com [comparar] mostra "—".
  final double? variacao;

  /// Mostra a linha de comparação com o período anterior.
  final bool comparar;
  final bool altaEhRuim;
  final bool destaque;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final fundo = destaque ? AppColors.primaryDark : AppColors.surface;
    final texto = destaque
        ? AppColors.textoContrastante(fundo)
        : (cor ?? AppColors.textPrimary);
    final secundario = destaque
        ? AppColors.textoContrastante(fundo)
        : AppColors.textSecondary;

    return Semantics(
      container: true,
      label: '$rotulo: $valor',
      child: Card(
        color: fundo,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rotulo,
                style: AppTextStyles.badge.copyWith(color: secundario),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valor,
                  style: AppTextStyles.money.copyWith(color: texto),
                ),
              ),
              if (detalhe != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detalhe!,
                  style: AppTextStyles.caption.copyWith(color: secundario),
                ),
              ],
              if (comparar) ...[
                const SizedBox(height: AppSpacing.xs),
                VariacaoPercentual(
                  variacao: variacao,
                  altaEhRuim: altaEhRuim,
                  corNeutra: secundario,
                  semFundoClaro: destaque,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Seta e percentual da variação, ou "—" sem base de comparação.
class VariacaoPercentual extends StatelessWidget {
  const VariacaoPercentual({
    required this.variacao,
    this.altaEhRuim = false,
    this.corNeutra = AppColors.textSecondary,
    this.semFundoClaro = false,
    this.compacto = false,
    super.key,
  });

  final double? variacao;

  /// Só a seta e o percentual (ou "—"), sem o "vs. anterior": para
  /// células de tabela (KAN-53).
  final bool compacto;
  final bool altaEhRuim;
  final Color corNeutra;
  final bool semFundoClaro;

  @override
  Widget build(BuildContext context) {
    final v = variacao;
    if (v == null) {
      return Text(
        compacto ? '—' : '— vs. período anterior',
        style: AppTextStyles.caption.copyWith(color: corNeutra),
      );
    }
    final arredondado = (v * 10).round() / 10;
    final subiu = arredondado > 0;
    final caiu = arredondado < 0;
    final bom = altaEhRuim ? caiu : subiu;
    final cor = semFundoClaro
        ? corNeutra
        : (!subiu && !caiu)
        ? corNeutra
        : (bom ? AppColors.scoreA : AppColors.statusInadimplente);
    final icone = subiu
        ? Icons.arrow_upward
        : caiu
        ? Icons.arrow_downward
        : Icons.remove;
    final texto =
        '${subiu ? '+' : ''}${arredondado.toStringAsFixed(1).replaceAll('.', ',')}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: cor),
        const SizedBox(width: 2),
        Text(texto, style: AppTextStyles.caption.copyWith(color: cor)),
        if (!compacto) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'vs. anterior',
              style: AppTextStyles.caption.copyWith(color: corNeutra),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
