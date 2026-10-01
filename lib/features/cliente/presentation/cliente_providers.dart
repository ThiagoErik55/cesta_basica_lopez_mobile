import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../data/cliente_model.dart';
import '../data/cliente_repository.dart';
import '../domain/status_pagamento.dart';

/// Filtros da listagem de clientes: termo de busca (já "debounced" pela
/// tela) e status de pagamento (`null` = todos).
class FiltroClientes {
  const FiltroClientes({this.termo = '', this.status});

  final String termo;
  final StatusPagamento? status;
}

final filtroClientesProvider =
    NotifierProvider<FiltroClientesNotifier, FiltroClientes>(
      FiltroClientesNotifier.new,
    );

class FiltroClientesNotifier extends Notifier<FiltroClientes> {
  @override
  FiltroClientes build() => const FiltroClientes();

  void buscar(String termo) =>
      state = FiltroClientes(termo: termo.trim(), status: state.status);

  void filtrarPorStatus(StatusPagamento? status) =>
      state = FiltroClientes(termo: state.termo, status: status);
}

/// Resultado da busca por nome (RF02). Termo vazio lista todos; caso
/// contrário, busca por prefixo do nome via repositório.
///
/// Observa só o termo: trocar o filtro de status não reabre o listener
/// do Firestore — o status é aplicado em memória em [clientesProvider].
final _clientesBuscadosProvider =
    StreamProvider.autoDispose<List<ClienteModel>>((ref) {
      final termo = ref.watch(filtroClientesProvider.select((f) => f.termo));
      final repositorio = ref.watch(clienteRepositoryProvider);
      return termo.isEmpty
          ? repositorio.observarTodos()
          : repositorio.buscarPorNome(termo);
    });

/// Lista exibida na tela de clientes: o resultado da busca por nome,
/// filtrado pelo status de pagamento selecionado (KAN-16).
final clientesProvider = Provider.autoDispose<AsyncValue<List<ClienteModel>>>((
  ref,
) {
  final status = ref.watch(filtroClientesProvider.select((f) => f.status));
  final buscados = ref.watch(_clientesBuscadosProvider);
  if (status == null) return buscados;
  return buscados.whenData(
    (lista) => lista.where((c) => statusPagamento(c) == status).toList(),
  );
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
