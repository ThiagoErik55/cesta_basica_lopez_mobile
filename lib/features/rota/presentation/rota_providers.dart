import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';
import '../../../core/utils/stream_com_cache.dart';
import '../../cliente/data/cliente_model.dart';
import '../data/rota_model.dart';
import '../data/rota_repository.dart';
import '../domain/associacao_rota.dart';
import '../domain/cadastro_rota.dart';

/// Rotas ativas em tempo real. Sem retentativa automática: o Riverpod 3
/// refaz providers que falham e mantém "carregando" durante as tentativas,
/// o que escondia o erro atrás de um spinner. Se o servidor não responde a
/// tempo, cai no cache local (mesmo padrão da KAN-41).
final rotasAtivasProvider = StreamProvider.autoDispose<List<RotaModel>>((ref) {
  final repositorio = ref.watch(rotaRepositoryProvider);
  return comFallbackDeCache<RotaModel>(
    repositorio.observarAtivas(),
    repositorio.ativasEmCache,
  );
}, retry: (_, _) => null);

/// Clientes ativos em **um** stream, para contar e listar os clientes de
/// cada rota em memória. Mesmo padrão de timeout e cache das rotas.
final clientesDasRotasProvider = StreamProvider.autoDispose<List<ClienteModel>>(
  (ref) {
    final repositorio = ref.watch(rotaRepositoryProvider);
    return comFallbackDeCache<ClienteModel>(
      repositorio.observarClientesAtivos(),
      repositorio.clientesAtivosEmCache,
    );
  },
  retry: (_, _) => null,
);

/// Rotas ativas com a contagem de clientes. O estado segue o das rotas
/// (carregando, erro ou dados); se os clientes ainda não chegaram ou
/// falharam, as rotas aparecem com a contagem desconhecida (`null`) em
/// vez de a tela inteira esperar ou falhar.
final itensRotaProvider = Provider.autoDispose<AsyncValue<List<ItemRota>>>((
  ref,
) {
  final rotas = ref.watch(rotasAtivasProvider);
  final clientes = ref.watch(clientesDasRotasProvider).value;
  return rotas.whenData((r) => montarItensRota(r, clientes));
});

/// `id → nome` das rotas ativas, para mostrar o nome da rota de um
/// cliente. Vazio enquanto as rotas carregam ou se falharem: sem nome, a
/// tela simplesmente não mostra a rota (não quebra).
final nomesDasRotasProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final rotas = ref.watch(rotasAtivasProvider).value ?? const [];
  return {for (final r in rotas) r.id: r.nome};
});

/// Termo de busca da lista de rotas (já com debounce da tela).
final buscaRotaProvider =
    NotifierProvider.autoDispose<BuscaRotaNotifier, String>(
      BuscaRotaNotifier.new,
    );

class BuscaRotaNotifier extends Notifier<String> {
  @override
  String build() => '';

  void buscar(String termo) => state = termo.trim();
}

/// Cadastro, edição e exclusão de rota (KAN-45). O estado expõe o
/// carregamento e o erro da última operação para a tela.
final salvarRotaProvider =
    AsyncNotifierProvider.autoDispose<SalvarRotaNotifier, void>(
      SalvarRotaNotifier.new,
    );

class SalvarRotaNotifier extends AsyncNotifier<void> {
  /// Quanto esperar a confirmação do servidor antes de considerar a
  /// escrita enfileirada offline (mesmo motivo do cadastro de produto).
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Cadastra uma rota nova. Lança [StateError] com a mensagem se o nome
  /// é inválido ou repete o de outra rota ativa; devolve se a escrita foi
  /// confirmada pelo servidor (`false` = salva no aparelho).
  Future<bool> cadastrar(DadosCadastraisRota dados) async {
    final nome = _nomeValido(dados.nome);
    final id = gerarId();
    return _escrever(
      () => ref
          .read(rotaRepositoryProvider)
          .salvar(
            RotaModel(
              id: id,
              // Código provisório derivado do UUID, como no produto e no
              // cliente: um sequencial central colidiria entre vendedores
              // cadastrando offline (ADR 001).
              codigo: 'R-${id.substring(0, 8).toUpperCase()}',
              nome: nome,
              linhaAtendimento: dados.linha,
              updatedAt: DateTime.now(),
            ),
          ),
    );
  }

  /// Atualiza só o que mudou em [original] (nome e/ou linha). O id fica,
  /// então os clientes associados continuam ligados. Sem mudança, não
  /// grava nada.
  Future<bool> atualizar(RotaModel original, DadosCadastraisRota dados) async {
    final nome = _nomeValido(dados.nome, idAtual: original.id);
    final mudouNome = nome != original.nome;
    final mudouLinha = dados.linha != original.linhaAtendimento;
    if (!mudouNome && !mudouLinha) return true;
    return _escrever(
      () => ref
          .read(rotaRepositoryProvider)
          .atualizar(
            original.id,
            nome: mudouNome ? nome : null,
            linhaAtendimento: mudouLinha ? dados.linha : null,
          ),
    );
  }

  /// Exclusão lógica. Lança [StateError] com a mensagem do bloqueio
  /// enquanto houver clientes associados (ver
  /// [motivoBloqueioExclusaoRota]). A contagem é a **atual** da lista, não
  /// a que a tela tinha ao abrir.
  Future<bool> excluir(String rotaId) async {
    final item = ref
        .read(itensRotaProvider)
        .value
        ?.where((i) => i.rota.id == rotaId)
        .firstOrNull;
    final motivo = motivoBloqueioExclusaoRota(item?.clientes);
    if (motivo != null) throw StateError(motivo);
    return _escrever(() => ref.read(rotaRepositoryProvider).remover(rotaId));
  }

  String _nomeValido(String nome, {String? idAtual}) {
    final erro = validarNomeRota(
      nome,
      rotas: ref.read(rotasAtivasProvider).value ?? const [],
      idAtual: idAtual,
    );
    if (erro != null) throw StateError(erro);
    return limparNomeRota(nome);
  }

  Future<bool> _escrever(Future<void> Function() escrita) async {
    state = const AsyncLoading();
    try {
      final sincronizado = await escrita()
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

/// Associação de clientes a rotas (KAN-46). O estado expõe o
/// carregamento e o erro da última gravação para a tela.
final associarClientesProvider =
    AsyncNotifierProvider.autoDispose<AssociarClientesNotifier, void>(
      AssociarClientesNotifier.new,
    );

class AssociarClientesNotifier extends AsyncNotifier<void> {
  /// Mesma espera de confirmação do cadastro de rota: offline, a escrita
  /// fica na fila local e a tela não pode esperar por ela.
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Aplica o [diff] do sheet à rota [rotaId]: grava só os clientes que
  /// mudaram (update parcial de `rotaId` e `updatedAt`). Sem mudanças,
  /// não grava nada. Lança [StateError] se a rota deixou de existir;
  /// devolve se o servidor confirmou (`false` = salvo no aparelho).
  Future<bool> aplicar(String rotaId, DiffAssociacao diff) async {
    _exigirRotaAtiva(rotaId);
    if (diff.semMudancas) return true;
    return _escrever(
      () => ref
          .read(rotaRepositoryProvider)
          .atribuirRotas(diff.novasRotas(rotaId)),
    );
  }

  /// Define (ou tira, com `null`) a rota de um único cliente: usado pelo
  /// detalhe do cliente.
  Future<bool> definirRotaDoCliente(String clienteId, String? rotaId) async {
    if (rotaId != null) _exigirRotaAtiva(rotaId);
    return _escrever(
      () => ref.read(rotaRepositoryProvider).atribuirRotas({clienteId: rotaId}),
    );
  }

  void _exigirRotaAtiva(String rotaId) {
    final rotas = ref.read(rotasAtivasProvider).value;
    if (rotas == null || rotaValida(rotaId, rotas) == null) {
      throw StateError('Esta rota não existe mais.');
    }
  }

  Future<bool> _escrever(Future<void> Function() escrita) async {
    state = const AsyncLoading();
    try {
      final sincronizado = await escrita()
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
