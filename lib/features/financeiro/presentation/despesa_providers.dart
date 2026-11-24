import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/stream_com_cache.dart';
import '../data/despesa_model.dart';
import '../data/despesa_repository.dart';
import '../domain/dia.dart';
import 'dia_financeiro_provider.dart';

/// Despesas do vendedor logado no dia selecionado (KAN-50), da mais
/// recente para a mais antiga. Lista vazia sem sessão.
///
/// Se o servidor não responde a tempo, cai no cache local (RNF06). Sem
/// retentativa automática, para um erro não ficar escondido atrás do
/// "carregando".
final despesasDoDiaProvider = StreamProvider.autoDispose<List<DespesaModel>>((
  ref,
) {
  final uid = ref.watch(usuarioLogadoProvider).value?.uid;
  if (uid == null) return Stream.value(const <DespesaModel>[]);
  final dia = ref.watch(diaFinanceiroProvider);
  final de = inicioDoDia(dia);
  final ate = inicioDoDiaSeguinte(dia);
  final repositorio = ref.watch(despesaRepositoryProvider);
  return comFallbackDeCache<DespesaModel>(
    repositorio.observarDoVendedor(uid, de: de, ate: ate),
    () => repositorio.doVendedorEmCache(uid, de: de, ate: ate),
  );
}, retry: (_, _) => null);

/// Lançamento, edição e exclusão de despesas (KAN-50). O estado expõe o
/// carregamento e o erro da última gravação para a tela.
final salvarDespesaProvider =
    AsyncNotifierProvider.autoDispose<SalvarDespesaNotifier, void>(
      SalvarDespesaNotifier.new,
    );

class SalvarDespesaNotifier extends AsyncNotifier<void> {
  /// Sem sinal, a escrita só é confirmada quando a conexão volta; a tela
  /// não espera por ela (a despesa já está no cache local).
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  FutureOr<void> build() {}

  /// Cria uma despesa nova ou, com [existente], atualiza a despesa.
  /// Os dados já foram validados por `avaliarDespesa`.
  ///
  /// Retorna `true` se o servidor confirmou e `false` se a escrita ficou
  /// na fila offline. Lança [StateError] sem sessão.
  Future<bool> salvar({
    DespesaModel? existente,
    required String descricao,
    required double valor,
    required DateTime data,
  }) {
    final DespesaModel despesa;
    if (existente != null) {
      despesa = existente.copyWith(
        descricao: descricao,
        valor: valor,
        data: _comHorario(data, existente.data),
      );
    } else {
      final uid = ref.read(usuarioLogadoProvider).value?.uid;
      if (uid == null) throw StateError('Sessão expirada.');
      final agora = DateTime.now();
      despesa = DespesaModel(
        id: gerarId(),
        vendedorUid: uid,
        descricao: descricao,
        valor: valor,
        data: _comHorario(data, agora),
        updatedAt: agora,
      );
    }
    return _executar(ref.read(despesaRepositoryProvider).salvar(despesa));
  }

  /// Exclusão lógica da despesa. Mesmo retorno de [salvar].
  Future<bool> remover(DespesaModel despesa) =>
      _executar(ref.read(despesaRepositoryProvider).remover(despesa.id));

  /// Junta o dia escolhido com o horário de [horario], para a lista do
  /// dia sair em ordem de lançamento.
  DateTime _comHorario(DateTime dia, DateTime horario) => DateTime(
    dia.year,
    dia.month,
    dia.day,
    horario.hour,
    horario.minute,
    horario.second,
  );

  Future<bool> _executar(Future<void> escrita) async {
    state = const AsyncLoading();
    try {
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