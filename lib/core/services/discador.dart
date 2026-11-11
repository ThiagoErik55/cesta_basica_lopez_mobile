import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre o discador do aparelho (KAN-47). Atrás de interface para os
/// fluxos serem testados com um fake.
abstract class Discador {
  /// Abre o discador com [uri] (`tel:`). `false` se não foi possível.
  Future<bool> ligar(Uri uri);
}

class DiscadorSistema implements Discador {
  const DiscadorSistema();

  @override
  Future<bool> ligar(Uri uri) async {
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

final discadorProvider = Provider<Discador>((ref) => const DiscadorSistema());
