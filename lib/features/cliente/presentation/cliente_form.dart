import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/cpf.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/cliente_model.dart';
import '../../rota/domain/associacao_rota.dart';
import '../../rota/presentation/rota_providers.dart';
import '../../rota/presentation/seletor_rota.dart';
import '../domain/dados_cadastrais_cliente.dart';

/// Formulário de dados cadastrais do cliente, compartilhado entre o
/// cadastro (RF01) e a edição (KAN-17): máscaras, validação de CPF e
/// campos obrigatórios ficam num lugar só.
///
/// Com [inicial], os campos já vêm preenchidos com os dados do cliente.
class ClienteForm extends ConsumerStatefulWidget {
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
  ConsumerState<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends ConsumerState<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.inicial?.nome);
  // O CPF e o telefone já são gravados com máscara, então entram no
  // controller como estão.
  late final _cpf = TextEditingController(text: widget.inicial?.cpf);
  late final _telefone = TextEditingController(text: widget.inicial?.telefone);
  late final _endereco = TextEditingController(text: widget.inicial?.endereco);
  // Valor cru do cliente; o seletor só o mostra se é de uma rota ativa.
  late String? _rotaId = widget.inicial?.rotaId;

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _endereco.dispose();
    super.dispose();
  }

  void _salvar() {
    if (widget.salvando || !_formKey.currentState!.validate()) return;
    // Com as rotas carregadas, só vale rota ativa (texto livre antigo ou
    // rota excluída viram "sem rota"). Sem elas (carregando ou erro), o
    // seletor está desabilitado e o valor original é mantido.
    final rotas = ref.read(rotasAtivasProvider).value;
    final rotaId = rotas == null ? _rotaId : rotaValida(_rotaId, rotas);
    widget.onSalvar(
      DadosCadastraisCliente(
        nome: _nome.text.trim(),
        cpf: _cpf.text,
        telefone: _telefone.text,
        endereco: _endereco.text.trim(),
        rotaId: rotaId,
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
          // Rotas reais do cadastro (KAN-45/46); grava o id da rota.
          SeletorRota(
            rotaId: _rotaId,
            onChanged: (v) => setState(() => _rotaId = v),
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
