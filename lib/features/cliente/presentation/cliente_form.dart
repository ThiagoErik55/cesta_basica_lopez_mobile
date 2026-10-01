import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/cpf.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/cliente_model.dart';
import '../domain/dados_cadastrais_cliente.dart';

/// Formulário de dados cadastrais do cliente, compartilhado entre o
/// cadastro (RF01) e a edição (KAN-17): máscaras, validação de CPF e
/// campos obrigatórios ficam num lugar só.
///
/// Com [inicial], os campos já vêm preenchidos com os dados do cliente.
class ClienteForm extends StatefulWidget {
  const ClienteForm({
    required this.textoBotao,
    required this.salvando,
    required this.onSalvar,
    this.inicial,
    super.key,
  });

  final ClienteModel? inicial;
  final String textoBotao;
  final bool salvando;
  final ValueChanged<DadosCadastraisCliente> onSalvar;

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.inicial?.nome);
  // O CPF e o telefone já são gravados com máscara, então entram no
  // controller como estão.
  late final _cpf = TextEditingController(text: widget.inicial?.cpf);
  late final _telefone = TextEditingController(text: widget.inicial?.telefone);
  late final _endereco = TextEditingController(text: widget.inicial?.endereco);
  late final _rota = TextEditingController(text: widget.inicial?.rotaId);

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _endereco.dispose();
    _rota.dispose();
    super.dispose();
  }

  void _salvar() {
    if (widget.salvando || !_formKey.currentState!.validate()) return;
    final rota = _rota.text.trim();
    widget.onSalvar(
      DadosCadastraisCliente(
        nome: _nome.text.trim(),
        cpf: _cpf.text,
        telefone: _telefone.text,
        endereco: _endereco.text.trim(),
        rotaId: rota.isEmpty ? null : rota,
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
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) => _obrigatorio(v, 'Informe o nome.'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _cpf,
            decoration: const InputDecoration(
              labelText: 'CPF',
              hintText: '000.000.000-00',
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [MascaraFormatter.cpf()],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o CPF.';
              if (!cpfValido(v)) return 'CPF inválido.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _telefone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              hintText: '(00) 00000-0000',
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [MascaraFormatter.telefone()],
            validator: (v) {
              final digitos = apenasDigitos(v ?? '');
              if (digitos.isEmpty) return 'Informe o telefone.';
              if (digitos.length < 10) return 'Telefone incompleto.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _endereco,
            decoration: const InputDecoration(labelText: 'Endereço'),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) => _obrigatorio(v, 'Informe o endereço.'),
          ),
          const SizedBox(height: AppSpacing.md),
          // LIMITAÇÃO: ainda não há tela nem repositório de rotas, então
          // a rota é um texto livre e opcional gravado direto em rotaId.
          // Quando o CRUD de rotas existir, trocar por um dropdown
          // alimentado pelo repositório de rotas (que grava o UUID).
          TextFormField(
            controller: _rota,
            decoration: const InputDecoration(
              labelText: 'Rota (opcional)',
              helperText: 'Texto livre até o cadastro de rotas existir.',
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _salvar(),
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
