import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'usuario_model.dart';

class UsuarioRepository {
  UsuarioRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('usuarios');

  Future<UserCredential> entrar(String email, String senha) =>
      _auth.signInWithEmailAndPassword(email: email, password: senha);

  Future<void> sair() => _auth.signOut();

  /// Lê usuarios/{uid}. Não depende do doc.id — o campo uid vem de
  /// dentro do próprio corpo do documento (ver comentário em
  /// usuario_model.dart).
  Future<UsuarioModel?> buscarPerfil(String uid) async {
    final doc = await _col.doc(uid).get();
    final data = doc.data();
    return data == null ? null : UsuarioModel.fromMap(data);
  }

  Future<void> salvarPerfil(UsuarioModel usuario) =>
      _col.doc(usuario.uid).set(usuario.toMap());
}

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  return UsuarioRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});
