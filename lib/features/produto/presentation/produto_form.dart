import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/produto_model.dart';
import '../domain/dados_cadastrais_produto.dart';

/// Formulário de dados cadastrais do produto, compartilhado entre o
/// cadastro e a edição (KAN-23): validação e máscara monetária ficam
/// num lugar só.
///
/// Com [inicial], os campos já vêm preenchidos com os dados do produto.
class ProdutoForm extends StatefulWidget {
  const ProdutoForm({
    required this.textoBotao,
    required this.salvando,
    required this.onSalvar,
    this.inicial,
    super.key,
  });

  final ProdutoModel? inicial;
  final String textoBotao;
  final bool salvando;
  final ValueChanged<DadosCadastraisProduto> onSalvar;

  @override
  State<ProdutoForm> createState() => _ProdutoFormState();
}

class _ProdutoFormState extends State<ProdutoForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.inicial?.nome);
  late final _marca = TextEditingController(text: widget.inicial?.marca);
  late final _categoria = TextEditingController(
    text: widget.inicial?.categoria,
  );
  late final _preco = TextEditingController(
    text: widget.inicial == null
        ? ''
        : formatarValorEditavel(widget.inicial!.preco),
  );
  late final _custoAtual = TextEditingController(
    text: formatarValorEditavel(widget.inicial?.custoAtual ?? 0),
  );
  late final _estoqueMinimo = TextEditingController(
    text: '${widget.inicial?.estoqueMinimo ?? 10}',
  );

  @override
  void dispose() {
    _nome.dispose();
    _marca.dispose();
    _categoria.dispose();
    _preco.dispose();
    _custoAtual.dispose();
    _estoqueMinimo.dispose();
    super.dispose();
  }

  void _salvar() {
    if (widget.salvando || !_formKey.currentState!.validate()) return;
    widget.onSalvar(
      DadosCadastraisProduto(
        nome: _nome.text.trim(),
        marca: _marca.text.trim(),
        categoria: _categoria.text.trim(),
        preco: lerValorMonetario(_preco.text)!,
        custoAtual: lerValorMonetario(_custoAtual.text) ?? 0,
        estoqueMinimo: int.parse(_estoqueMinimo.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextFormField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome'),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) => _obrigatorio(v, 'Informe o nome.'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _marca,
            decoration: const InputDecoration(labelText: 'Marca'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) => _obrigatorio(v, 'Informe a marca.'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _categoria,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              hintText: 'Grãos, enlatados, limpeza...',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) => _obrigatorio(v, 'Informe a categoria.'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _preco,
            decoration: const InputDecoration(
              labelText: 'Preço de venda',
              prefixText: r'R$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [valorMonetarioFormatter],
            validator: (v) {
              final valor = lerValorMonetario(v ?? '');
              if (valor == null) return 'Informe o preço.';
              if (valor <= 0) return 'O preço deve ser maior que zero.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _custoAtual,
            decoration: const InputDecoration(
              labelText: 'Custo atual',
              prefixText: r'R$ ',
              helperText: 'Custo da última compra, usado na apuração de lucro.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [valorMonetarioFormatter],
            validator: (v) {
              final valor = lerValorMonetario(v ?? '');
              if (valor == null) return 'Informe o custo.';
              if (valor < 0) return 'O custo não pode ser negativo.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _estoqueMinimo,
            decoration: const InputDecoration(
              labelText: 'Estoque mínimo',
              helperText: 'Limite para o alerta de estoque baixo.',
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _salvar(),
            validator: (v) {
              final valor = int.tryParse(v ?? '');
              if (valor == null) return 'Informe o estoque mínimo.';
              if (valor < 0) return 'O estoque mínimo não pode ser negativo.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            texto: widget.textoBotao,
            carregando: widget.salvando,
            onPressed: _salvar,
          ),
        ],
      ),
    );
  }

  static String? _obrigatorio(String? valor, String mensagem) =>
      (valor == null || valor.trim().isEmpty) ? mensagem : null;
}
