import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/controle_estoque.dart';
import '../domain/entrada_estoque.dart';
import 'entrada_estoque_providers.dart';
import 'estoque_providers.dart';

/// Abre o registro de entrada de estoque (KAN-42). Com [produtoId], o
/// produto já vem escolhido (detalhe do estoque); sem ele, o sheet começa
/// pela busca do produto.
Future<void> registrarEntradaSheet(BuildContext context, {String? produtoId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RegistrarEntradaSheet(produtoId: produtoId),
    );

class RegistrarEntradaSheet extends ConsumerStatefulWidget {
  const RegistrarEntradaSheet({this.produtoId, super.key});

  final String? produtoId;

  @override
  ConsumerState<RegistrarEntradaSheet> createState() =>
      _RegistrarEntradaSheetState();
}

class _RegistrarEntradaSheetState extends ConsumerState<RegistrarEntradaSheet> {
  final _busca = TextEditingController();
  final _quantidade = TextEditingController();
  final _custo = TextEditingController();
  final _observacao = TextEditingController();
  late String? _produtoId = widget.produtoId;
  DateTime _data = DateTime.now();
  bool _custoPreenchido = false;
  bool _tentou = false;

  @override
  void dispose() {
    _busca.dispose();
    _quantidade.dispose();
    _custo.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      helpText: 'Data da entrada',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  void _trocarProduto() => setState(() {
    _produtoId = null;
    _custoPreenchido = false;
    _custo.clear();
  });

  Future<void> _confirmar(ResultadoEntrada r, ItemEstoque item) async {
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final registrada = await ref
          .read(registrarEntradaProvider.notifier)
          .registrar(
            produtoId: item.produto.id,
            quantidade: r.quantidade!,
            custoUnitario: r.novoCusto!,
            data: _data,
            observacao: _observacao.text,
          );
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            'Entrada registrada: +${registrada.quantidade} un.'
            '${registrada.sincronizado ? '' : ' Salva no aparelho: será enviada quando houver conexão.'}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao registrar entrada: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a entrada. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itens = ref.watch(itensEstoqueProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: itens.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) {
          debugPrint('Erro ao carregar produtos da entrada: $error');
          return const EmptyState(
            icone: Icons.error_outline,
            titulo: 'Erro ao carregar os produtos',
            descricao: 'Verifique a conexão e tente novamente.',
          );
        },
        data: (todos) {
          final item = todos
              .where((i) => i.produto.id == _produtoId)
              .firstOrNull;
          if (item == null) {
            return _escolhaDeProduto(todos, naoEncontrado: _produtoId != null);
          }
          return _formulario(item);
        },
      ),
    );
  }

  Widget _escolhaDeProduto(
    List<ItemEstoque> todos, {
    required bool naoEncontrado,
  }) {
    final resultados = ordenarEstoque(filtrarEstoque(todos, termo: _busca.text))
        .toList();
    resultados.sort(
      (a, b) =>
          a.produto.nome.toLowerCase().compareTo(b.produto.nome.toLowerCase()),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Registrar entrada', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          naoEncontrado
              ? 'Produto não encontrado. Escolha outro.'
              : 'Escolha o produto que recebeu estoque.',
          style: AppTextStyles.cardSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _busca,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Buscar por nome, marca ou código',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: resultados.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icone: Icons.search_off,
                    titulo: 'Nenhum produto encontrado',
                    descricao: 'Ajuste a busca.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: resultados.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final p = resultados[i].produto;
                    return ListTile(
                      title: Text(p.nome, style: AppTextStyles.cardTitle),
                      subtitle: Text(
                        '${p.marca} · ${p.codigo} · estoque ${p.estoqueAtual}',
                        style: AppTextStyles.cardSubtitle,
                      ),
                      onTap: () => setState(() {
                        _produtoId = p.id;
                        _custoPreenchido = false;
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _formulario(ItemEstoque item) {
    final p = item.produto;
    if (!_custoPreenchido) {
      // Custo padrão: o da última compra, que é o custoAtual do produto.
      _custo.text = p.custoAtual > 0 ? formatarValorEditavel(p.custoAtual) : '';
      _custoPreenchido = true;
    }

    final salvando = ref.watch(registrarEntradaProvider).isLoading;
    final r = avaliarEntrada(
      quantidade: _quantidade.text,
      custo: lerValorMonetario(_custo.text),
      data: _data,
      agora: DateTime.now(),
      estoqueAtual: p.estoqueAtual,
      custoAtual: p.custoAtual,
    );

    // Erros só aparecem depois de o campo ser tocado ou da primeira
    // tentativa de confirmar, para o formulário não abrir "vermelho".
    String? erro(String? mensagem, TextEditingController c) =>
        _tentou || c.text.isNotEmpty ? mensagem : null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Registrar entrada', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.nome} · ${p.marca} · ${p.codigo}',
                  style: AppTextStyles.cardSubtitle,
                ),
              ),
              if (widget.produtoId == null)
                TextButton(
                  onPressed: salvando ? null : _trocarProduto,
                  child: const Text('Trocar produto'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantidade,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Quantidade',
              suffixText: 'un.',
              errorText: erro(r.erroQuantidade, _quantidade),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _custo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [valorMonetarioFormatter],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Custo unitário',
              prefixText: r'R$ ',
              helperText: 'Vira o custo atual do produto (última compra).',
              errorText: erro(r.erroCusto, _custo),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Expanded(
                child: Text('Data da entrada', style: AppTextStyles.body),
              ),
              TextButton.icon(
                onPressed: _escolherData,
                icon: const Icon(Icons.event),
                label: Text(formatarData(_data)),
              ),
            ],
          ),
          if (r.erroData case final e?)
            Text(
              e,
              style: AppTextStyles.caption.copyWith(color: AppColors.scoreD),
            ),
          TextField(
            controller: _observacao,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              helperText: 'Ex.: fornecedor ou nº da nota de compra.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Previa(resultado: r),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            texto: 'Confirmar entrada',
            carregando: salvando,
            onPressed: () {
              if (!r.ok) {
                setState(() => _tentou = true);
                return;
              }
              _confirmar(r, item);
            },
          ),
        ],
      ),
    );
  }
}

class _Previa extends StatelessWidget {
  const _Previa({required this.resultado});

  final ResultadoEntrada resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final estilo = AppTextStyles.body.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w600,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estoque: ${r.estoqueAtual} → '
              '${r.estoqueApos?.toString() ?? '—'}',
              style: estilo,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Custo: ${formatarMoeda(r.custoAtual)} → '
              '${r.novoCusto == null ? '—' : formatarMoeda(r.novoCusto!)}',
              style: estilo,
            ),
            if (r.saldoNegativoAntes) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'O saldo atual está negativo (${r.estoqueAtual}): houve venda '
                'acima do estoque registrado.'
                '${r.estoqueApos == null ? '' : ' Depois da entrada o saldo '
                          'será ${r.estoqueApos}.'}',
                style: AppTextStyles.caption.copyWith(color: AppColors.scoreD),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
