import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/regra_bloqueio_provider.dart';
import '../../venda/presentation/promissorias_providers.dart';
import '../data/rota_model.dart';
import '../domain/agenda_vendedor.dart';
import '../domain/associacao_rota.dart';
import 'rota_providers.dart';

/// Relógio da agenda: de onde vem "hoje". Atrás de um provider para os
/// testes fixarem a data.
final agendaRelogioProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// O que o vendedor escolheu na agenda: data, rota, filtro rápido e busca.
/// Fica só na tela (sem persistência, sem estado global): sair da aba e
/// voltar mantém, fechar o app volta para hoje.
class SelecaoAgenda {
  const SelecaoAgenda({
    required this.data,
    this.rotaId,
    this.filtro = FiltroAgenda.todos,
    this.termo = '',
  });

  /// Dia escolhido (sem hora).
  final DateTime data;

  /// `null` = todas as rotas.
  final String? rotaId;
  final FiltroAgenda filtro;
  final String termo;

  SelecaoAgenda copyWith({
    DateTime? data,
    FiltroAgenda? filtro,
    String? termo,
  }) => SelecaoAgenda(
    data: data ?? this.data,
    rotaId: rotaId,
    filtro: filtro ?? this.filtro,
    termo: termo ?? this.termo,
  );

  /// Troca a rota (inclusive para `null`, "todas").
  SelecaoAgenda comRota(String? rotaId) =>
      SelecaoAgenda(data: data, rotaId: rotaId, filtro: filtro, termo: termo);
}

final selecaoAgendaProvider =
    NotifierProvider.autoDispose<SelecaoAgendaNotifier, SelecaoAgenda>(
      SelecaoAgendaNotifier.new,
    );

class SelecaoAgendaNotifier extends Notifier<SelecaoAgenda> {
  @override
  SelecaoAgenda build() =>
      SelecaoAgenda(data: soData(ref.read(agendaRelogioProvider)()));

  DateTime get _hoje => soData(ref.read(agendaRelogioProvider)());

  bool get hoje => state.data == _hoje;

  void irParaHoje() => state = state.copyWith(data: _hoje);

  void escolherData(DateTime data) =>
      state = state.copyWith(data: soData(data));

  /// Dia anterior, por dia de calendário (não por 24 h: a virada do
  /// horário de verão não pula nem repete dia).
  void diaAnterior() => escolherData(
    DateTime(state.data.year, state.data.month, state.data.day - 1),
  );

  void proximoDia() => escolherData(
    DateTime(state.data.year, state.data.month, state.data.day + 1),
  );

  void escolherRota(String? rotaId) => state = state.comRota(rotaId);

  void filtrar(FiltroAgenda filtro) => state = state.copyWith(filtro: filtro);

  void buscar(String termo) => state = state.copyWith(termo: termo.trim());
}

/// A agenda de uma data e rota, ainda sem busca nem filtro rápido.
class AgendaDoDia {
  const AgendaDoDia({
    required this.itens,
    required this.resumo,
    required this.rotas,
    required this.rotaId,
    required this.parcelasDisponiveis,
  });

  /// Clientes da rota (ou de todas), na data escolhida.
  final List<ItemAgenda> itens;
  final ResumoAgenda resumo;

  /// Rotas ativas, para o seletor.
  final List<RotaModel> rotas;

  /// Rota efetivamente usada: a escolhida, se ainda é uma rota ativa; se
  /// foi excluída enquanto estava escolhida, volta para "todas" (`null`).
  final String? rotaId;

  /// `false` enquanto as parcelas carregam (ou se falharem): os destaques
  /// vêm do resumo do cliente e o "a receber" não é calculado.
  final bool parcelasDisponiveis;
}

/// Agenda em tempo real. Junta, **sem listener por cliente**:
/// - as rotas ativas e os clientes ativos (KAN-45, um stream cada, com
///   fallback para o cache);
/// - as parcelas pendentes, pelo mesmo `promissoriasProvider` da tela de
///   Promissórias (um stream de vendas parceladas + um por venda
///   parcelada).
///
/// Rotas e clientes são obrigatórios: sem eles o estado é carregando ou
/// erro (e o carregamento vira erro pelo fallback, sem spinner infinito).
/// As parcelas são um complemento: se demoram ou falham, a agenda aparece
/// com [AgendaDoDia.parcelasDisponiveis] `false`.
final agendaProvider = Provider.autoDispose<AsyncValue<AgendaDoDia>>((ref) {
  final selecao = ref.watch(selecaoAgendaProvider);
  final rotas = ref.watch(rotasAtivasProvider);
  final clientes = ref.watch(clientesDasRotasProvider);
  final regra = ref.watch(regraBloqueioProvider);
  final agora = ref.watch(agendaRelogioProvider)();

  final listaRotas = rotas.value;
  final listaClientes = clientes.value;
  if (listaRotas == null || listaClientes == null) {
    final erro = rotas.hasError ? rotas : clientes;
    return erro.hasError
        ? AsyncValue.error(erro.error!, erro.stackTrace!)
        : const AsyncValue.loading();
  }

  // Só observa as parcelas depois que rotas e clientes chegaram.
  final promissorias = ref.watch(promissoriasProvider(null)).value;
  final porCliente = promissorias == null
      ? null
      : parcelasPendentesPorCliente(promissorias);

  final rotaId = rotaValida(selecao.rotaId, listaRotas);
  final itens = montarAgenda(
    clientes: listaClientes,
    rotas: listaRotas,
    data: selecao.data,
    rotaId: rotaId,
    parcelasPendentesPorCliente: porCliente,
    regra: regra,
    agora: agora,
  );
  return AsyncValue.data(
    AgendaDoDia(
      itens: itens,
      resumo: resumirAgenda(itens),
      rotas: listaRotas,
      rotaId: rotaId,
      parcelasDisponiveis: porCliente != null,
    ),
  );
});
