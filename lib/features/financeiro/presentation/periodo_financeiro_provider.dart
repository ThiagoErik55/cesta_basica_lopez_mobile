import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/periodo.dart';

/// Período exibido no painel financeiro (KAN-52). Começa na semana atual.
final periodoFinanceiroProvider =
    NotifierProvider<PeriodoFinanceiroNotifier, Periodo>(
      PeriodoFinanceiroNotifier.new,
    );

class PeriodoFinanceiroNotifier extends Notifier<Periodo> {
  @override
  Periodo build() => Periodo.semana(DateTime.now());

  /// Troca para Hoje, Semana ou Mês, calculados a partir de agora.
  /// O personalizado precisa das datas: use [personalizar].
  void selecionar(TipoPeriodo tipo) {
    final agora = DateTime.now();
    state = switch (tipo) {
      TipoPeriodo.hoje => Periodo.hoje(agora),
      TipoPeriodo.semana => Periodo.semana(agora),
      TipoPeriodo.mes => Periodo.mes(agora),
      TipoPeriodo.personalizado => state,
    };
  }

  /// Intervalo escolhido pelo usuário, do dia [de] ao dia [ate]
  /// (incluídos). Passa de [maximoDiasPersonalizado] dias, é encurtado.
  void personalizar(DateTime de, DateTime ate) =>
      state = Periodo.personalizado(de, ate);
}
