import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/regra_bloqueio_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../rota/data/rota_repository.dart';
import '../../rota/domain/associacao_rota.dart';
import '../../rota/presentation/rota_providers.dart';
import '../data/cliente_model.dart';
import '../data/cliente_repository.dart';
import '../domain/bloqueio_cliente.dart';
import '../domain/dados_cadastrais_cliente.dart';
import '../domain/status_pagamento.dart';

/// Filtros da listagem de clientes: termo de busca (já "debounced" pela
/// tela), status de pagamento (`null` = todos) e rota (KAN-46).
class FiltroClientes {
  const FiltroClientes({
    this.termo = '',
    this.status,
    this.rota = const FiltroRotaCliente.todas(),
  });

  final String termo;
  final StatusPagamento? status;
  final FiltroRotaCliente rota;
}

final filtroClientesProvider =
    NotifierProvider<FiltroClientesNotifier, FiltroClientes>(
      FiltroClientesNotifier.new,
    );

class FiltroClientesNotifier extends Notifier<FiltroClientes> {
  @override
  FiltroClientes build() => const FiltroClientes();

  void buscar(String termo) => state = FiltroClientes(
    termo: termo.trim(),
    status: state.status,
    rota: state.rota,
  );

  void filtrarPorStatus(StatusPagamento? status) => state = FiltroClientes(
    termo: state.termo,
    status: status,
    rota: state.rota,
  );

  void filtrarPorRota(FiltroRotaCliente rota) => state = FiltroClientes(
    termo: state.termo,
    status: state.status,
    rota: rota,
  );
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
/// filtrado pelo status de pagamento selecionado (KAN-16). O status
/// inclui o bloqueio automático por atraso ou limite (KAN-35), então o
/// filtro "Bloqueado" também traz os bloqueados pela regra.
final clientesProvider = Provider.autoDispose<AsyncValue<List<ClienteModel>>>((
  ref,
) {
  final status = ref.watch(filtroClientesProvider.select((f) => f.status));
  final filtroRota = ref.watch(filtroClientesProvider.select((f) => f.rota));
  final buscados = ref.watch(_clientesBuscadosProvider);
  if (status == null && !filtroRota.ativo) return buscados;
  final regra = ref.watch(regraBloqueioProvider);
  // Rotas ativas (KAN-45): cliente com rota excluída ou inexistente conta
  // como "sem rota". `null` enquanto carregam.
  final rotas = filtroRota.ativo ? ref.watch(rotasAtivasProvider).value : null;
  return buscados.whenData(
    (lista) => lista
        .where(
          (c) =>
              (status == null ||
                  situacaoDoClientePeloResumo(c, regra: regra).status ==
                      status) &&
              clientePassaNoFiltroDeRota(c, filtroRota, rotas),
        )
        .toList(),
  );
});

/// Cliente por id, para a tela de detalhes (KAN-17). `null` quando não
/// existe ou foi removido. É invalidado por [SalvarClienteNotifier]
/// após uma edição, para a tela recarregar os dados.
final clientePorIdProvider = FutureProvider.autoDispose
    .family<ClienteModel?, String>((ref, id) {
      return ref.watch(clienteRepositoryProvider).buscarPorId(id);
    });

/// Cadastro (RF01) e edição (KAN-17) de cliente. O estado expõe o
/// carregamento e o erro do último salvamento para a tela; a montagem
/// do [ClienteModel] fica aqui, fora da UI.
final salvarClienteProvider =
    AsyncNotifierProvider.autoDispose<SalvarClienteNotifier, void>(
      SalvarClienteNotifier.new,
    );

class SalvarClienteNotifier extends AsyncNotifier<void> {
  /// Quanto esperar a confirmação do servidor antes de considerar a
  /// escrita enfileirada offline. Sem sinal (RNF06), o Future do
  /// Firestore só completa quando a conexão volta — mas o documento já
  /// está no cache local e aparece na listagem imediatamente.
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Cadastra um cliente novo. Score, limite de crédito e bloqueado
  /// ficam com os padrões do model (B, 0, não bloqueado).
  ///
  /// Retorna `true` se o servidor confirmou a escrita, ou `false` se ela
  /// ficou na fila offline do Firestore. Erros são propagados e também
  /// ficam disponíveis no [state].
  Future<bool> cadastrar(DadosCadastraisCliente dados) async {
    _exigirRotaAtiva(dados.rotaId);
    final id = gerarId();
    return _gravar(
      ClienteModel(
        id: id,
        // Código interno provisório derivado do UUID: um sequencial
        // (C001, C002...) exigiria um contador central, que colidiria
        // entre os dois vendedores cadastrando offline (ADR 001).
        codigo: 'C-${id.substring(0, 8).toUpperCase()}',
        nome: dados.nome,
        cpf: dados.cpf,
        telefone: dados.telefone,
        endereco: dados.endereco,
        rotaId: dados.rotaId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Atualiza os dados cadastrais de [original], mantendo id, código e
  /// todos os campos de crédito. Mesmo retorno de [cadastrar].
  ///
  /// A rota (KAN-46) é gravada à parte, só quando o vendedor realmente a
  /// mudou, por update parcial de `rotaId` e `updatedAt` pela camada de
  /// rota. Texto livre antigo ou rota excluída contam como "sem rota":
  /// salvar sem mexer na rota não limpa nem altera esse valor.
  ///
  /// Limite: o cadastro continua sendo gravado inteiro por
  /// `ClienteRepository.salvar` (que esta task não altera), então, se a
  /// rota do cliente mudou em outro aparelho entre abrir e salvar a
  /// edição, o valor antigo é regravado.
  Future<bool> atualizar(
    ClienteModel original,
    DadosCadastraisCliente dados,
  ) async {
    _exigirRotaAtiva(dados.rotaId);
    var sincronizado = await _atualizarExistente(
      original,
      nome: dados.nome,
      cpf: dados.cpf,
      telefone: dados.telefone,
      endereco: dados.endereco,
      rotaId: original.rotaId,
    );

    final rotas = ref.read(rotasAtivasProvider).value;
    final atual = rotas == null
        ? original.rotaId
        : rotaValida(original.rotaId, rotas);
    if (dados.rotaId != atual) {
      sincronizado =
          await _gravarRota(original.id, dados.rotaId) && sincronizado;
      ref.invalidate(clientePorIdProvider(original.id));
    }
    return sincronizado;
  }

  /// Atualiza score, limite de crédito e bloqueio de [original] (KAN-20),
  /// mantendo os dados cadastrais. Mesmo retorno de [cadastrar].
  ///
  /// Valores definidos manualmente pelo vendedor até existirem (a) o
  /// histórico de vendas para o cálculo automático do score (Sprint 4)
  /// e (b) a definição da empresa sobre a regra de bloqueio por atraso
  /// (RF30, pendência do modelo lógico).
  Future<bool> atualizarCredito(
    ClienteModel original, {
    required ScoreCliente score,
    required double limiteCredito,
    required bool bloqueado,
  }) => _atualizarExistente(
    original,
    rotaId: original.rotaId,
    score: score,
    limiteCredito: limiteCredito,
    bloqueado: bloqueado,
  );

  /// Grava [original] com os campos informados trocados, mantendo id,
  /// código e o resto. Recarrega os detalhes desse cliente ao final.
  ///
  /// Monta o model direto em vez de usar [ClienteModel.copyWith], que
  /// não aceita CPF e não consegue limpar a rota (null mantém o valor).
  /// Por isso [rotaId] é obrigatório: `null` aqui apaga a rota.
  Future<bool> _atualizarExistente(
    ClienteModel original, {
    required String? rotaId,
    String? nome,
    String? cpf,
    String? telefone,
    String? endereco,
    ScoreCliente? score,
    double? limiteCredito,
    bool? bloqueado,
  }) async {
    final sincronizado = await _gravar(
      ClienteModel(
        id: original.id,
        codigo: original.codigo,
        nome: nome ?? original.nome,
        cpf: cpf ?? original.cpf,
        telefone: telefone ?? original.telefone,
        endereco: endereco ?? original.endereco,
        rotaId: rotaId,
        score: score ?? original.score,
        limiteCredito: limiteCredito ?? original.limiteCredito,
        bloqueado: bloqueado ?? original.bloqueado,
        ultimaCompra: original.ultimaCompra,
        proximoVencimento: original.proximoVencimento,
        valorEmAberto: original.valorEmAberto,
        updatedAt: DateTime.now(),
        deleted: original.deleted,
      ),
    );
    ref.invalidate(clientePorIdProvider(original.id));
    return sincronizado;
  }

  /// Rota escolhida precisa existir e estar ativa. Sem as rotas
  /// carregadas não dá para conferir, e o formulário mantém o valor
  /// original nesse caso.
  void _exigirRotaAtiva(String? rotaId) {
    if (rotaId == null) return;
    final rotas = ref.read(rotasAtivasProvider).value;
    if (rotas != null && rotaValida(rotaId, rotas) == null) {
      throw StateError('Esta rota não existe mais. Escolha outra.');
    }
  }

  Future<bool> _gravarRota(String clienteId, String? rotaId) async {
    state = const AsyncLoading();
    try {
      final escrita = ref.read(rotaRepositoryProvider).atribuirRotas({
        clienteId: rotaId,
      });
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

  Future<bool> _gravar(ClienteModel cliente) async {
    state = const AsyncLoading();
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
