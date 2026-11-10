import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/assinatura.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

VendaModel _venda(String? assinatura) => VendaModel(
  id: 'v',
  clienteId: 'c',
  clienteNome: 'M',
  vendedorUid: 'u',
  numeroNota: 1,
  data: DateTime(2026),
  itens: const [],
  valorTotal: 0,
  tipo: TipoVenda.aVista,
  assinaturaBase64: assinatura,
  updatedAt: DateTime(2026),
);

void main() {
  group('traço mínimo', () {
    test('sem traço ou só um ponto não basta', () {
      expect(tracoSuficiente(const []), isFalse);
      expect(
        tracoSuficiente([
          [const Offset(10, 10)],
        ]),
        isFalse,
      );
      expect(
        tracoSuficiente([
          [const Offset(10, 10), const Offset(12, 11)],
        ]),
        isFalse,
      );
    });

    test('um traço longo basta', () {
      expect(
        tracoSuficiente([
          [const Offset(0, 0), const Offset(100, 0)],
        ]),
        isTrue,
      );
    });

    test('soma vários traços curtos', () {
      final curtos = [
        for (var i = 0; i < 4; i++) [Offset(0, i * 10), Offset(20, i * 10)],
      ];
      expect(comprimentoDosTracos(curtos), 80);
      expect(tracoSuficiente(curtos), isTrue);
    });
  });

  group('escala de redução', () {
    test('até 100 KB não reduz', () {
      expect(escalaDeReducao(30 * 1024), isNull);
      expect(escalaDeReducao(100 * 1024), isNull);
    });

    test('acima de 100 KB reduz mirando 50 KB', () {
      final f = escalaDeReducao(200 * 1024)!;
      expect(f, closeTo(0.5, 0.001));
    });

    test('nunca reduz a menos de 30%', () {
      expect(escalaDeReducao(100 * 1024 + 1), closeTo(0.707, 0.001));
      expect(escalaDeReducao(100000 * 1024), 0.3);
    });
  });

  group('decodificação segura', () {
    test('PNG válido', () {
      final bytes = decodificarAssinatura(base64Encode(_png));
      expect(bytes, isNotNull);
      expect(bytes, _png);
    });

    test('nulo, vazio e só espaços', () {
      expect(decodificarAssinatura(null), isNull);
      expect(decodificarAssinatura(''), isNull);
      expect(decodificarAssinatura('   '), isNull);
    });

    test('base64 inválido', () {
      expect(decodificarAssinatura('isto não é base64!!'), isNull);
    });

    test('base64 válido que não é imagem', () {
      expect(
        decodificarAssinatura(base64Encode(utf8.encode('olá mundo'))),
        isNull,
      );
      expect(decodificarAssinatura(base64Encode(Uint8List(3))), isNull);
    });
  });

  group('venda já assinada', () {
    test('com assinatura utilizável', () {
      expect(vendaAssinada(_venda(base64Encode(_png))), isTrue);
    });

    test('sem assinatura ou com assinatura corrompida', () {
      expect(vendaAssinada(_venda(null)), isFalse);
      expect(vendaAssinada(_venda('')), isFalse);
      expect(vendaAssinada(_venda('@@@')), isFalse);
    });
  });
}
