import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cliente/domain/regra_bloqueio.dart';

/// Regra de bloqueio automático em vigor (KAN-35).
///
/// Hoje devolve o padrão. É o ponto único para trocar a regra: quando a
/// empresa definir os valores (ou eles vierem de `configuracoes/geral`),
/// só este provider muda; telas e cálculos já leem a regra daqui.
final regraBloqueioProvider = Provider<RegraBloqueio>(
  (ref) => regraBloqueioPadrao,
);
