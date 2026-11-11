import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/estoque/domain/regra_estoque.dart';

/// Política de estoque insuficiente em vigor (KAN-43).
///
/// Hoje devolve o padrão. É o ponto único para trocar a regra: telas e
/// cálculos já leem a regra daqui.
final regraEstoqueProvider = Provider<RegraEstoque>(
  (ref) => regraEstoquePadrao,
);
