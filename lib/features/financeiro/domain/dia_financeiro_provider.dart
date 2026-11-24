import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dia.dart';

/// Dia exibido no financeiro (despesas e saldo do dia). Começa em hoje e
/// é compartilhado entre as telas: trocar o dia em uma vale na outra.
final diaFinanceiroProvider = NotifierProvider<DiaFinanceiroNotifier, DateTime>(
  DiaFinanceiroNotifier.new,
);

class DiaFinanceiroNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => inicioDoDia(DateTime.now());

  void selecionar(DateTime dia) => state = inicioDoDia(dia);

  void anterior() => state = DateTime(state.year, state.month, state.day - 1);

  /// Não avança além de hoje: não há despesa nem venda no futuro.
  void proximo() {
    final seguinte = DateTime(state.year, state.month, state.day + 1);
    if (!seguinte.isAfter(inicioDoDia(DateTime.now()))) state = seguinte;
  }

  void hoje() => state = inicioDoDia(DateTime.now());
}