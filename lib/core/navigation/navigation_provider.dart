import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Índice da aba selecionada na navegação principal (KAN-10).
///
/// `StateProvider` foi movido para `package:flutter_riverpod/legacy.dart`
/// no Riverpod 3.x — aqui usamos o `NotifierProvider` padrão para não
/// depender da API legada.
final abaSelecionadaProvider = NotifierProvider<AbaSelecionadaNotifier, int>(
  AbaSelecionadaNotifier.new,
);

class AbaSelecionadaNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selecionar(int indice) => state = indice;
}
