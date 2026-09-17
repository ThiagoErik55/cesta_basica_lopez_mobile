import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../providers/firebase_providers.dart';
import 'main_shell.dart';

/// Decide entre login e navegação principal conforme o estado de
/// autenticação (KAN-11), usando o usuarioLogadoProvider já existente
/// (authStateChanges) — sem lógica de roteamento duplicada em outro
/// lugar do app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioLogadoProvider);

    return usuario.when(
      data: (user) => user == null ? const LoginScreen() : const MainShell(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Sem sessão confirmada, o caminho mais seguro é pedir login de
      // novo em vez de assumir acesso.
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
