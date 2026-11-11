import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/rota/domain/regra_recomendacao.dart';

/// Regra de recomendação de clientes a visitar em vigor (KAN-48).
///
/// Hoje devolve o padrão. É o ponto único para trocar a regra (por
/// exemplo, lendo de `configuracoes/geral` quando a empresa definir os
/// pesos): telas e cálculos já leem a regra daqui.
final regraRecomendacaoProvider = Provider<RegraRecomendacao>(
  (ref) => regraRecomendacaoPadrao,
);
