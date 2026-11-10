import 'dart:typed_data';

import 'package:cesta_basica_lopez_mobile/core/services/compartilhador_pdf.dart';
import 'package:cesta_basica_lopez_mobile/core/services/envio_whatsapp.dart';
import 'package:cesta_basica_lopez_mobile/core/services/whatsapp_sharer.dart';
import 'package:flutter_test/flutter_test.dart';

class _SharerFalso implements WhatsappSharer {
  _SharerFalso({this.resultado = ResultadoWhatsapp.compartilhado, this.erro});

  final ResultadoWhatsapp resultado;
  final Object? erro;
  String? telefoneRecebido;
  String? mensagemRecebida;
  int chamadas = 0;

  @override
  Future<ResultadoWhatsapp> enviar({
    required Uint8List bytes,
    required String nomeArquivo,
    required String mensagem,
    String? telefone,
  }) async {
    chamadas++;
    telefoneRecebido = telefone;
    mensagemRecebida = mensagem;
    if (erro != null) throw erro!;
    return resultado;
  }
}

class _CompartilhadorFalso implements CompartilhadorPdf {
  _CompartilhadorFalso({this.falha = false});

  final bool falha;
  int chamadas = 0;
  String? mensagemRecebida;

  @override
  Future<void> compartilhar({
    required Uint8List bytes,
    required String nomeArquivo,
    String? mensagem,
  }) async {
    chamadas++;
    mensagemRecebida = mensagem;
    if (falha) throw StateError('sem folha');
  }
}

Future<DesfechoEnvioWhatsapp> _enviar(
  _SharerFalso sharer,
  _CompartilhadorFalso fallback,
  String? telefone,
) => enviarPorWhatsapp(
  sharer: sharer,
  fallback: fallback,
  bytes: Uint8List(3),
  nomeArquivo: 'nota.pdf',
  mensagem: 'Olá!',
  telefoneCliente: telefone,
);

void main() {
  test('telefone válido: normaliza e passa ao sharer', () async {
    final sharer = _SharerFalso();
    final fallback = _CompartilhadorFalso();
    final r = await _enviar(sharer, fallback, '(45) 99999-0001');
    expect(r, DesfechoEnvioWhatsapp.compartilhado);
    expect(sharer.telefoneRecebido, '5545999990001');
    expect(sharer.mensagemRecebida, 'Olá!');
    expect(fallback.chamadas, 0);
  });

  test('telefone inválido: segue sem número e avisa', () async {
    final sharer = _SharerFalso();
    final r = await _enviar(sharer, _CompartilhadorFalso(), '123');
    expect(r, DesfechoEnvioWhatsapp.compartilhadoSemTelefone);
    expect(sharer.telefoneRecebido, isNull);
    expect(sharer.chamadas, 1);
  });

  test('web: chat aberto só com o texto', () async {
    final r = await _enviar(
      _SharerFalso(resultado: ResultadoWhatsapp.chatSemArquivo),
      _CompartilhadorFalso(),
      '45999990001',
    );
    expect(r, DesfechoEnvioWhatsapp.chatSemArquivo);
  });

  test(
    'WhatsApp ausente: cai no compartilhamento comum com a mensagem',
    () async {
      final fallback = _CompartilhadorFalso();
      final r = await _enviar(
        _SharerFalso(resultado: ResultadoWhatsapp.naoInstalado),
        fallback,
        '45999990001',
      );
      expect(r, DesfechoEnvioWhatsapp.fallbackCompartilhamento);
      expect(fallback.chamadas, 1);
      expect(fallback.mensagemRecebida, 'Olá!');
    },
  );

  test('erro no envio: também cai no compartilhamento comum', () async {
    final fallback = _CompartilhadorFalso();
    final r = await _enviar(
      _SharerFalso(erro: StateError('boom')),
      fallback,
      '45999990001',
    );
    expect(r, DesfechoEnvioWhatsapp.fallbackCompartilhamento);
    expect(fallback.chamadas, 1);
  });

  test('WhatsApp ausente e fallback falhando: falha', () async {
    final r = await _enviar(
      _SharerFalso(resultado: ResultadoWhatsapp.naoInstalado),
      _CompartilhadorFalso(falha: true),
      null,
    );
    expect(r, DesfechoEnvioWhatsapp.falha);
  });
}
