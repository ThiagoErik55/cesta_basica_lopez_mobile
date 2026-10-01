import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/cpf.dart';
import '../../../core/utils/mascaras.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/primary_button.dart';
import 'cliente_providers.dart';

/// Cadastro de cliente (RF01). Score, limite de crédito e bloqueado não
/// são editados aqui — o cliente nasce com os padrões do model.
class CadastroClienteScreen extends ConsumerStatefulWidget {
  const CadastroClienteScreen({super.key});

  @override
  ConsumerState<CadastroClienteScreen> createState() =>
      _CadastroClienteScreenState();
}

class _CadastroClienteScreenState extends ConsumerState<CadastroClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _telefone = TextEditingController();
  final _endereco = TextEditingController();
  final _rota = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _endereco.dispose();
    _rota.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final rota = _rota.text.trim();

    try {
      final sincronizado = await ref
          .read(cadastroClienteProvider.notifier)
          .salvar(
            nome: _nome.text,
            cpf: _cpf.text,
            telefone: _telefone.text,
            endereco: _endereco.text,
            rotaId: rota.isEmpty ? null : rota,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Cliente cadastrado.'
                : 'Cliente cadastrado. Será sincronizado quando houver '
                      'conexão.',
          ),
        ),
      );
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o cliente. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salvando = ref.watch(cadastroClienteProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Cliente'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: Form(
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
              texto: 'Salvar',
              carregando: salvando,
              onPressed: _salvar,
            ),
          ],
        ),
      ),
    );
  }

  static String? _obrigatorio(String? valor, String mensagem) =>
      (valor == null || valor.trim().isEmpty) ? mensagem : null;
}
