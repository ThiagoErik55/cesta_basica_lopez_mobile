import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../data/cliente_model.dart';
import '../data/cliente_repository.dart';

/// Lista de clientes para a tela de listagem (RF02), parametrizada pelo
/// termo de busca já "debounced" pela tela. Termo vazio lista todos;
/// caso contrário, busca por prefixo do nome via repositório.
///
/// autoDispose: cada termo digitado abre um listener no Firestore, e o
/// listener do termo anterior precisa ser fechado quando a tela passa a
/// observar o termo novo.
final clientesProvider = StreamProvider.autoDispose
    .family<List<ClienteModel>, String>((ref, termo) {
      final repositorio = ref.watch(clienteRepositoryProvider);
      final buscado = termo.trim();
      return buscado.isEmpty
          ? repositorio.observarTodos()
          : repositorio.buscarPorNome(buscado);
    });

/// Cliente por id, usado pela tela de detalhes (placeholder até o card
/// de Detalhes do Cliente).
final clientePorIdProvider = FutureProvider.autoDispose
    .family<ClienteModel?, String>((ref, id) {
      return ref.watch(clienteRepositoryProvider).buscarPorId(id);
    });

/// Cadastro de cliente (RF01). O estado expõe o carregamento e o erro do
/// último salvamento para a tela; a montagem do [ClienteModel] fica
/// aqui, fora da UI.
final cadastroClienteProvider =
    AsyncNotifierProvider.autoDispose<CadastroClienteNotifier, void>(
      CadastroClienteNotifier.new,
    );

class CadastroClienteNotifier extends AsyncNotifier<void> {
  /// Quanto esperar a confirmação do servidor antes de considerar a
  /// escrita enfileirada offline. Sem sinal (RNF06), o Future do
  /// Firestore só completa quando a conexão volta — mas o documento já
  /// está no cache local e aparece na listagem imediatamente.
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Salva o cliente e retorna `true` se o servidor confirmou a escrita,
  /// ou `false` se ela ficou na fila offline do Firestore. Erros são
  /// propagados e também ficam disponíveis no [state].
  ///
  /// Score, limite de crédito e bloqueado ficam com os padrões do model
  /// (B, 0, não bloqueado) — são definidos em outros fluxos.
  Future<bool> salvar({
    required String nome,
    required String cpf,
    required String telefone,
    required String endereco,
    String? rotaId,
  }) async {
    state = const AsyncLoading();
    final id = gerarId();
    final cliente = ClienteModel(
      id: id,
      // Código interno provisório derivado do UUID: um sequencial
      // (C001, C002...) exigiria um contador central, que colidiria
      // entre os dois vendedores cadastrando offline (ADR 001).
      codigo: 'C-${id.substring(0, 8).toUpperCase()}',
      nome: nome.trim(),
      cpf: cpf,
      telefone: telefone,
      endereco: endereco.trim(),
      rotaId: rotaId,
      updatedAt: DateTime.now(),
    );

    try {
      final escrita = ref.read(clienteRepositoryProvider).salvar(cliente);
      final sincronizado = await escrita
          .then((_) => true)
          .timeout(_esperaConfirmacao, onTimeout: () => false);
      state = const AsyncData(null);
      return sincronizado;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
