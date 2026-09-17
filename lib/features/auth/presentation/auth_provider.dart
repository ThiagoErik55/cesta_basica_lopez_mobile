import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/usuario_model.dart';
import '../data/usuario_repository.dart';

/// Perfil (usuarios/{uid}) do usuário autenticado no momento. `null`
/// enquanto não há sessão, ou se o documento ainda não existir.
///
/// O estado de "logado ou não" em si vem de [usuarioLogadoProvider]
/// (core/providers/firebase_providers.dart, authStateChanges) — este
/// provider só busca dados complementares de exibição, nunca decide
/// roteamento.
final perfilUsuarioProvider = FutureProvider<UsuarioModel?>((ref) async {
  final usuario = ref.watch(usuarioLogadoProvider).value;
  if (usuario == null) return null;
  return ref.watch(usuarioRepositoryProvider).buscarPerfil(usuario.uid);
});

/// Controla a ação de login: carregando, erro e sucesso. A tradução do
/// erro do Firebase para uma mensagem em português acontece na tela
/// (login_screen.dart), não aqui — este controller só expõe o
/// resultado bruto via AsyncValue.
final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);

class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> entrar(String email, String senha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(usuarioRepositoryProvider).entrar(email, senha),
    );
  }
}
