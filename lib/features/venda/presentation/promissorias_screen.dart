import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/controle_promissorias.dart';
import 'promissorias_providers.dart';

/// Controle de promissórias (RF20, KAN-34): todas as vendas parceladas,
/// com situação, saldo e próximo vencimento. É uma visão derivada de
/// vendas e parcelas, sem coleção própria.
///
/// Com [clienteId], mostra só as promissórias desse cliente (aberta pelo
/// detalhe do cliente). Tocar num item abre o detalhe da venda, onde
/// ficam as parcelas, o registro de pagamento (KAN-33) e a alteração de
/// valor (KAN-32).
class PromissoriasScreen extends ConsumerStatefulWidget {
  const PromissoriasScreen({this.clienteId, super.key});

  final String? clienteId;

  @override
  ConsumerState<PromissoriasScreen> createState() => _PromissoriasScreenState();
}

class _PromissoriasScreenState extends ConsumerState<PromissoriasScreen> {
  final _busca = TextEditingController();
  StatusPromissoria? _situacao;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promissorias = ref.watch(promissoriasProvider(widget.clienteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clienteId == null ? 'Promissórias' : 'Promissórias do cliente',
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: promissorias.when(
        data: _conteudo,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          // Erro comum: índice ausente no Firestore (ver
          // firestore.indexes.json).
          debugPrint('Erro ao carregar promissórias: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar promissórias',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }

  Widget _conteudo(List<ItemPromissoria> todas) {
    if (todas.isEmpty) {
      return const Center(
        child: EmptyState(
          icone: Icons.receipt_long_outlined,
          titulo: 'Nenhuma promissória',
          descricao: 'As vendas parceladas aparecem aqui.',
        ),
      );
    }

    final itens = ordenarPromissorias(
      filtrarPromissorias(todas, situacao: _situacao, termo: _busca.text),
    );

    return Column(
      children: [
        // O resumo considera todas as promissórias, não só as filtradas.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _Resumo(resumo: resumirPromissorias(todas)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ValueListenableBuilder(
            valueListenable: _busca,
            builder: (context, valor, _) => TextField(
              controller: _busca,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nota ou cliente',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: valor.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_busca.clear),
                      ),
              ),
            ),
          ),
        ),
        FilterChipBar<StatusPromissoria>(
          opcoes: const [
            OpcaoFiltro('Todas', null),
            OpcaoFiltro('Em dia', StatusPromissoria.aberta),
            OpcaoFiltro('Em atraso', StatusPromissoria.atrasada),
            OpcaoFiltro('Quitadas', StatusPromissoria.paga),
          ],
          selecionado: _situacao,
          onSelecionar: (s) => setState(() => _situacao = s),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: itens.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icone: Icons.search_off,
                      titulo: 'Nenhuma promissória encontrada',
                      descricao: 'Ajuste a busca ou o filtro de situação.',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  itemCount: itens.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CardPromissoria(
                    item: itens[i],
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.detalheVenda,
                      arguments: itens[i].vendaId,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.resumo});

  final ResumoPromissorias resumo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Total(
              rotulo: 'Em aberto',
              valor: formatarMoeda(resumo.totalEmAberto),
            ),
            _Total(
              rotulo: 'Em atraso',
              valor: formatarMoeda(resumo.totalEmAtraso),
              cor: resumo.totalEmAtraso > 0 ? AppColors.scoreD : null,
            ),
            _Total(
              rotulo: 'Atrasadas',
              valor: '${resumo.quantidadeEmAtraso}',
              cor: resumo.quantidadeEmAtraso > 0 ? AppColors.scoreD : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.rotulo, required this.valor, this.cor});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(valor, style: AppTextStyles.money.copyWith(color: cor)),
        ],
      ),
    );
  }
}

class _CardPromissoria extends StatelessWidget {
  const _CardPromissoria({required this.item, required this.onTap});

  final ItemPromissoria item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final proximo = item.proximoVencimento;

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nota ${item.numeroNota}',
                          style: AppTextStyles.cardTitle,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(item.clienteNome, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Situacao(item.situacao),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${formatarData(item.data)} · total '
                '${formatarMoeda(item.valorTotal)}',
                style: AppTextStyles.cardSubtitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pago ${formatarMoeda(item.valorPago)}',
                      style: AppTextStyles.cardSubtitle,
                    ),
                  ),
                  Text(
                    'Saldo ${formatarMoeda(item.saldo)}',
                    style: AppTextStyles.money,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${item.parcelasPagas}/${item.totalParcelas} parcelas pagas'
                '${proximo == null ? '' : ' · próx. venc. ${formatarData(proximo)}'}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Situacao extends StatelessWidget {
  const _Situacao(this.situacao);

  final StatusPromissoria situacao;

  @override
  Widget build(BuildContext context) => switch (situacao) {
    StatusPromissoria.aberta => const StatusBadge.emDia(),
    StatusPromissoria.atrasada => const StatusBadge.emAtraso(),
    StatusPromissoria.paga => const StatusBadge('Quitada', AppColors.offline),
  };
}
