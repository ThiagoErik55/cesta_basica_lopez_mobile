import 'package:cesta_basica_lopez_mobile/core/utils/whatsapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarTelefoneWhatsApp', () {
    test('com máscara', () {
      expect(normalizarTelefoneWhatsApp('(45) 99999-0001'), '5545999990001');
      expect(normalizarTelefoneWhatsApp('(45) 3225-1234'), '554532251234');
    });

    test('10 e 11 dígitos sem máscara', () {
      expect(normalizarTelefoneWhatsApp('4532251234'), '554532251234');
      expect(normalizarTelefoneWhatsApp('45999990001'), '5545999990001');
    });

    test('já com 55, com ou sem sinal de +', () {
      expect(normalizarTelefoneWhatsApp('+55 45 99999-0001'), '5545999990001');
      expect(normalizarTelefoneWhatsApp('554532251234'), '554532251234');
    });

    test('DDD 55 (RS) não é confundido com o código do país', () {
      expect(normalizarTelefoneWhatsApp('55999990001'), '5555999990001');
      expect(normalizarTelefoneWhatsApp('5532221234'), '555532221234');
    });

    test('curto demais, longo demais, vazio, nulo e letras', () {
      expect(normalizarTelefoneWhatsApp('99999000'), isNull);
      expect(normalizarTelefoneWhatsApp('455532251234999'), isNull);
      expect(normalizarTelefoneWhatsApp(''), isNull);
      expect(normalizarTelefoneWhatsApp(null), isNull);
      expect(normalizarTelefoneWhatsApp('abcdefghijk'), isNull);
    });

    test('DDD inválido e celular sem o 9', () {
      expect(normalizarTelefoneWhatsApp('05999990001'), isNull);
      expect(normalizarTelefoneWhatsApp('45899990001'), isNull);
    });
  });

  group('linkWhatsApp', () {
    test('com telefone e mensagem codificada com %20', () {
      final u = linkWhatsApp(
        mensagem: 'Olá, Maria! Tudo bem?',
        telefoneWhatsApp: '5545999990001',
      );
      expect(u.host, 'wa.me');
      expect(u.path, '/5545999990001');
      expect(u.toString(), contains('text=Ol%C3%A1%2C%20Maria'));
      expect(u.queryParameters['text'], 'Olá, Maria! Tudo bem?');
    });

    test('sem telefone abre wa.me/ só com o texto', () {
      final u = linkWhatsApp(mensagem: 'oi');
      expect(u.toString(), 'https://wa.me/?text=oi');
    });
  });

  test('primeiroNome', () {
    expect(primeiroNome('Maria da Silva'), 'Maria');
    expect(primeiroNome('  João  '), 'João');
    expect(primeiroNome('Cher'), 'Cher');
    expect(primeiroNome('   '), isNull);
    expect(primeiroNome(''), isNull);
  });
}
