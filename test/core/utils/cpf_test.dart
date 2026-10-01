import 'package:cesta_basica_lopez_mobile/core/utils/cpf.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/mascaras.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _aplicar(TextInputFormatter f, String texto) => f
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texto))
    .text;

void main() {
  group('cpfValido', () {
    test('aceita CPF válido com e sem máscara', () {
      expect(cpfValido('529.982.247-25'), isTrue);
      expect(cpfValido('52998224725'), isTrue);
    });

    test('rejeita dígito verificador errado', () {
      expect(cpfValido('529.982.247-24'), isFalse);
      expect(cpfValido('123.456.789-00'), isFalse);
    });

    test('rejeita sequência repetida e tamanho errado', () {
      expect(cpfValido('111.111.111-11'), isFalse);
      expect(cpfValido('5299822472'), isFalse);
      expect(cpfValido(''), isFalse);
    });
  });

  group('MascaraFormatter', () {
    test('CPF', () {
      expect(_aplicar(MascaraFormatter.cpf(), '52998224725'), '529.982.247-25');
      expect(_aplicar(MascaraFormatter.cpf(), '5299'), '529.9');
      expect(
        _aplicar(MascaraFormatter.cpf(), '529982247251234'),
        '529.982.247-25',
      );
    });

    test('telefone fixo e celular', () {
      expect(
        _aplicar(MascaraFormatter.telefone(), '4532221234'),
        '(45) 3222-1234',
      );
      expect(
        _aplicar(MascaraFormatter.telefone(), '45999990001'),
        '(45) 99999-0001',
      );
      expect(_aplicar(MascaraFormatter.telefone(), '45'), '(45');
    });
  });
}
