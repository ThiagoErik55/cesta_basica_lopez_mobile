import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/primary_button.dart';
import '../../produto/data/produto_model.dart';
import '../data/venda_model.dart';
import '../domain/troca.dart';
import 'nova_venda_providers.dart';
import 'pos_venda_providers.dart';
import 'seletor_quantidade.dart';

/// Troca de produto em venda registrada (RF25, KAN-28).
Future<void> registrarTroca(BuildContext context, VendaModel venda) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TrocaSheet(venda: venda),
    );

class _TrocaSheet extends ConsumerStatefulWidget {
  const _TrocaSheet({required this.venda});

  final VendaModel venda;

  @override
  ConsumerState<_TrocaSheet> createState() => _TrocaSheetState();
}

class _TrocaSheetState extends ConsumerState<_TrocaSheet> {
  // Guarda ids, não objetos: a lista de produtos vem de um stream e é
  // recriada a cada atualização, e o Dropdown compara valores por ==.
  String? _originalId;
  String? _novoId;
  int _quantidade = 1;

  ItemVenda? get _original {
    for (final i in widget.venda.itens) {
      if (i.id == _originalId) return i;
    }
    return null;
  }

  ProdutoModel? _produtoNovo(List<ProdutoModel> produtos) {
    for (final p in produtos) {
      if (p.id == _novoId) return p;
    }
    return null;
  }

  int get _maximo {
    final original = _original;
    return original == null ? 0 : quantidadeTrocavel(widget.venda, original);
  }

  Future<void> _confirmar(ItemVenda original, ProdutoModel novo) async {

    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final sincronizado = await ref
          .read(posVendaProvider.notifier)
          .registrarTroca(
            venda: widget.venda,
            original: original,
            novo: novo,
            quantidade: _quantidade,
          );
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Troca registrada.'
                : 'Troca salva no aparelho. Será enviada quando houver '
                      'conexão.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao registrar troca: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a troca. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtos = ref.watch(produtosVendaProvider).value ?? const [];
    final salvando = ref.watch(posVendaProvider).isLoading;
    final itensTrocaveis = widget.venda.itens
        .where((i) => quantidadeTrocavel(widget.venda, i) > 0)
        .toList();
    final original = _original;
    final novo = _produtoNovo(produtos);
    final opcoesNovo = produtos
        .where((p) => p.id != original?.produtoId)
        .toList();
    final diferenca = original != null && novo != null
        ? diferencaTroca(
            original: original,
            novo: novo,
            quantidade: _quantidade,
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Registrar troca', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            if (itensTrocaveis.isEmpty)
              const Text(
                'Todos os itens desta venda já foram trocados.',
                style: AppTextStyles.body,
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _originalId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Produto devolvido',
                ),
                items: [
                  for (final item in itensTrocaveis)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.nome} '
                        '(até ${quantidadeTrocavel(widget.venda, item)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _originalId = id;
                  _quantidade = 1;
                  // O produto novo não pode ser o mesmo devolvido.
                  if (_original?.produtoId == _novoId) _novoId = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                // A key recria o campo quando o produto novo é limpo.
                key: ValueKey(_novoId),
                initialValue: novo?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Produto entregue no lugar',
                ),
                items: [
                  for (final p in opcoesNovo)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.nome} · ${formatarMoeda(p.preco)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _novoId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(
                    child: Text('Quantidade', style: AppTextStyles.body),
                  ),
                  SeletorQuantidade(
                    quantidade: _quantidade,
                    onAdicionar: () {
                      if (_quantidade < _maximo) {
                        setState(() => _quantidade++);
                      }
                    },
                    onRemover: () {
                      if (_quantidade > 1) setState(() => _quantidade--);
                    },
                  ),
                ],
              ),
              if (diferenca != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  switch (diferenca) {
                    > 0 => 'Cliente paga ${formatarMoeda(diferenca)} de '
                        'diferença.',
                    < 0 => 'Devolver ${formatarMoeda(-diferenca)} ao '
                        'cliente.',
                    _ => 'Sem diferença de valor.',
                  },
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                texto: 'Confirmar troca',
                carregando: salvando,
                onPressed: original != null && novo != null
                    ? () => _confirmar(original, novo)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
