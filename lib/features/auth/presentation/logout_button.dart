import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/usuario_repository.dart';

/// Botão de sair (KAN-11), usado no cabeçalho de cada aba do MainShell.
///
/// Não navega manualmente: encerrar a sessão muda o authStateChanges, e
/// o AuthGate (core/navigation/auth_gate.dart) leva de volta ao login
/// sozinho.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Sair',
      onPressed: () => ref.read(usuarioRepositoryProvider).sair(),
    );
  }
}
