import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cesta_basica_lopez_mobile/features/venda/data/assinatura_renderer.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/assinatura.dart';
import 'package:flutter_test/flutter_test.dart';

List<Offset> _linha(double largura) => [
  for (var x = 0.0; x <= largura; x += 4)
    Offset(x, 50 + 20 * (x % 8 == 0 ? 1 : -1)),
];

Future<Image> _decodificar(Uint8List png) async {
  final codec = await instantiateImageCodec(png);
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('gera PNG pequeno, limitado a 600 px de largura', (t) async {
    await t.runAsync(() async {
      final png = await renderizarAssinatura([_linha(1500)]);
      expect(decodificarAssinatura(base64Encode(png)), isNotNull);
      final img = await _decodificar(png);
      expect(img.width, lessThanOrEqualTo(larguraMaximaAssinatura));
      expect(png.length, lessThan(tamanhoMaximoAssinatura));
    });
  });

  testWidgets('recusa assinatura sem traço suficiente', (t) async {
    await t.runAsync(() async {
      await expectLater(
        renderizarAssinatura([
          [const Offset(1, 1)],
        ]),
        throwsArgumentError,
      );
    });
  });
}
