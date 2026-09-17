import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/conectividade_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_provider.dart';

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Tela de login (KAN-11). O protótipo pedia só o nome do vendedor, mas
/// isso não é implementável: as Security Rules do Firestore exigem
/// `request.auth != null`, então a decisão registrada é e-mail e senha
/// com sessão persistida (o vendedor entra uma vez só). O visual do
/// protótipo (logo, slogan, badge de conectividade, rodapé com as
/// linhas de atendimento) foi mantido — só o campo de nome virou
/// e-mail + senha.
///
/// Não há cadastro nem recuperação de senha aqui: as contas de Neiva e
/// Manuel já foram criadas manualmente no console do Firebase.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginControllerProvider.notifier)
        .entrar(_emailController.text.trim(), _senhaController.text);
  }

  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Digite seu e-mail.';
    if (!_regexEmail.hasMatch(email)) return 'Digite um e-mail válido.';
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite sua senha.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final estadoLogin = ref.watch(loginControllerProvider);
    final online = ref.watch(conectividadeProvider).value ?? false;
    final carregando = estadoLogin.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.topCenter,
                  child: ConnectionBadge(),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Center(child: _Logotipo()),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Cesta Básica Lopez',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Venda porta a porta, direto do seu bolso',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  enabled: !carregando,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: _validarEmail,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _senhaController,
                  enabled: !carregando,
                  obscureText: !_senhaVisivel,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: carregando
                          ? null
                          : () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                  ),
                  validator: _validarSenha,
                ),
                if (estadoLogin.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _traduzirErroLogin(estadoLogin.error!, online: online),
                    style: AppTextStyles.body.copyWith(color: AppColors.scoreD),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  texto: 'Entrar',
                  carregando: carregando,
                  onPressed: _entrar,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Linhas de atendimento: Toledo e Regional',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logotipo extends StatelessWidget {
  const _Logotipo();

  static const double _tamanho = AppSpacing.xl * 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tamanho,
      height: _tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Icon(
        Icons.storefront_outlined,
        size: AppSpacing.xl,
        color: AppColors.textoContrastante(AppColors.primaryDark),
      ),
    );
  }
}

/// Traduz erros do login para mensagens em português que fazem sentido
/// pra um vendedor em campo — nunca o código bruto do Firebase.
///
/// user-not-found, wrong-password e invalid-credential viram a mesma
/// mensagem de propósito: não é papel do app revelar se o e-mail existe
/// ou se foi a senha que errou.
///
/// network-request-failed é o caso do RNF06 que não tem contorno: no
/// primeiro login em um aparelho, sem conexão, não há sessão em cache
/// pra usar — diferente de um vendedor já logado antes, que continua
/// autenticado offline normalmente. A mensagem avisa isso, em vez de
/// parecer um erro de credencial.
String _traduzirErroLogin(Object erro, {required bool online}) {
  if (erro is FirebaseAuthException) {
    switch (erro.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'invalid-email':
        return 'Digite um e-mail válido.';
      case 'too-many-requests':
        return 'Muitas tentativas seguidas. Aguarde um pouco e tente '
            'de novo.';
      case 'network-request-failed':
        return online
            ? 'Não foi possível conectar ao servidor. Tente novamente.'
            : 'Sem conexão com a internet. O primeiro acesso em cada '
                  'aparelho exige internet — depois de entrar uma vez, '
                  'o app funciona offline normalmente.';
    }
  }
  return 'Não foi possível entrar. Tente novamente.';
}
