import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/regra_recomendacao_provider.dart';
import '../domain/agenda_vendedor.dart';
import '../domain/recomendacao_visita.dart';
import 'agenda_providers.dart';

/// Clientes dispensados da recomendação, por data da agenda (KAN-48).
///
/// Vive só na memória do app: reiniciar devolve todos. Cada dispensa vale
/// para a data em que foi feita, então trocar a data da agenda mostra de
/// volta quem foi dispensado em outro dia. Persistir isso (para valer
/// entre aparelhos ou depois de fechar o app) dependeria da entidade
/// VISITA, hoje sem uso, ou de campo novo no cliente; esta task não cria
/// nenhum dos dois.
final dispensadosHojeProvider =
    NotifierProvider.autoDispose<
      DispensadosNotifier,
      Map<DateTime, Set<String>>
    >(DispensadosNotifier.new);

class DispensadosNotifier extends Notifier<Map<DateTime, Set<String>>> {
  @override
  Map<DateTime, Set<String>> build() => const {};

  /// Dispensa [clienteId] na [data] da agenda.
  void dispensar(String clienteId, DateTime data) {
    final dia = soData(data);
    state = {
      ...state,
      dia: {...?state[dia], clienteId},
    };
  }

  /// Devolve todos os dispensados da [data].
  void restaurar(DateTime data) {
    final dia = soData(data);
    if (!state.containsKey(dia)) return;
    state = {...state}..remove(dia);
  }
}

/// O que o bloco do topo e a lista completa mostram.
class RecomendacoesDoDia {
  const RecomendacoesDoDia({
    required this.todas,
    required this.melhores,
    required this.dispensados,
    required this.parcelasDisponiveis,
    required this.data,
  });

  /// Todos os clientes com motivo para visitar, do mais prioritário ao
  /// menos, sem os dispensados.
  final List<Recomendacao> todas;

  /// Os primeiros N de [todas] (N da regra), para o bloco do topo.
  final List<Recomendacao> melhores;

  /// Quantos clientes foram dispensados nesta data (e saíram da lista).
  final int dispensados;

  /// `false` enquanto as parcelas carregam: as recomendações são
  /// estimadas pelo resumo do cliente.
  final bool parcelasDisponiveis;

  /// Data da agenda.
  final DateTime data;
}

/// Recomendações da data e da rota escolhidas na agenda.
///
/// Deriva do [agendaProvider]: **não abre nenhum listener novo**. Rotas,
/// clientes e parcelas são as mesmas assinaturas da agenda, e mudar a
/// data, a rota ou os dispensados só recalcula em memória. O estado
/// (carregando ou erro) é o da agenda, com o mesmo timeout e fallback
/// para o cache.
final recomendacoesProvider =
    Provider.autoDispose<AsyncValue<RecomendacoesDoDia>>((ref) {
      final agenda = ref.watch(agendaProvider);
      final data = ref.watch(selecaoAgendaProvider.select((s) => s.data));
      final dispensados = ref.watch(
        dispensadosHojeProvider.select((m) => m[soData(data)] ?? const {}),
      );
      final regra = ref.watch(regraRecomendacaoProvider);
      final hoje = ref.watch(agendaRelogioProvider)();

      return agenda.whenData((a) {
        final todas = recomendarVisitas(
          a.itens,
          regra: regra,
          data: data,
          hoje: hoje,
          dispensados: dispensados,
        );
        return RecomendacoesDoDia(
          todas: todas,
          melhores: melhoresRecomendacoes(todas, regra),
          dispensados: dispensados.length,
          parcelasDisponiveis: a.parcelasDisponiveis,
          data: soData(data),
        );
      });
    });
