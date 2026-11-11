import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/id_generator.dart';
import '../data/estoque_repository.dart';
import '../domain/entrada_estoque.dart';

/// Resultado de [RegistrarEntradaNotifier.registrar].
class EntradaRegistrada {
  const EntradaRegistrada({
    required this.quantidade,
    required this.sincronizado,
  });

  final int quantidade;

  /// `false` quando o servidor não confirmou a tempo (sem conexão): a
  /// entrada fica salva no aparelho e sobe quando a conexão voltar.
  final bool sincronizado;
}

/// Entrada de estoque (KAN-42). O estado expõe o carregamento e o erro do
/// último registro para a tela; a montagem do movimento fica aqui, fora
/// da UI.
final registrarEntradaProvider =
    AsyncNotifierProvider.autoDispose<RegistrarEntradaNotifier, void>(
      RegistrarEntradaNotifier.new,
    );

class RegistrarEntradaNotifier extends AsyncNotifier<void> {
  /// Quanto esperar a confirmação do servidor antes de considerar a
  /// entrada "salva no aparelho". O batch offline só completa quando a
  /// conexão volta, então a tela não pode esperar por ele.
  static const _esperaConfirmacao = Duration(seconds: 3);

  @override
  void build() {}

  /// Registra a entrada. Os dados já foram validados por
  /// [avaliarEntrada]; aqui só se monta o movimento e se grava. Lança
  /// [StateError] sem sessão ou com dados inválidos, e repassa o erro de
  /// gravação.
  Future<EntradaRegistrada> registrar({
    required String produtoId,
    required int quantidade,
    required double custoUnitario,
    required DateTime data,
    String? observacao,
  }) async {
    final vendedorUid = ref.read(usuarioLogadoProvider).value?.uid;
    if (vendedorUid == null) throw StateError('Sessão expirada.');
    if (quantidade <= 0 || custoUnitario <= 0) {
      throw StateError('Entrada inválida.');
    }

    final entrada = montarMovimentoEntrada(
      id: gerarId(),
      produtoId: produtoId,
      quantidade: quantidade,
      custoUnitario: custoUnitario,
      data: data,
      vendedorUid: vendedorUid,
      observacao: observacao,
      agora: DateTime.now(),
    );

    state = const AsyncLoading();
    try {
      final escrita = ref
          .read(estoqueRepositoryProvider)
          .registrarEntrada(entrada);
      final sincronizado = await escrita
          .then((_) => true)
          .timeout(_esperaConfirmacao, onTimeout: () => false);
      state = const AsyncData(null);
      return EntradaRegistrada(
        quantidade: quantidade,
        sincronizado: sincronizado,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
