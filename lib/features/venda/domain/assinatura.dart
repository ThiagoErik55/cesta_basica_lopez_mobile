import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../data/venda_model.dart';

/// Regras puras da assinatura digital do cliente (KAN-38).

/// Comprimento mínimo, em pixels da tela, somando todos os traços, para
/// contar como assinatura (evita um ponto ou um toque sem querer).
const double tracoMinimoAssinatura = 60;

/// Largura máxima da imagem gravada.
const int larguraMaximaAssinatura = 600;

/// Acima disto a imagem é reduzida e gerada de novo.
const int tamanhoMaximoAssinatura = 100 * 1024;

/// Tamanho que a redução tenta atingir.
const int tamanhoAlvoAssinatura = 50 * 1024;

/// Soma dos comprimentos de todos os [tracos].
double comprimentoDosTracos(List<List<Offset>> tracos) {
  var total = 0.0;
  for (final traco in tracos) {
    for (var i = 1; i < traco.length; i++) {
      total += (traco[i] - traco[i - 1]).distance;
    }
  }
  return total;
}

/// A assinatura tem traço suficiente para ser confirmada.
bool tracoSuficiente(List<List<Offset>> tracos) =>
    comprimentoDosTracos(tracos) >= tracoMinimoAssinatura;

/// Fator de escala (0 a 1) para gerar a imagem de novo quando ela passou
/// de [tamanhoMaximoAssinatura], ou `null` se o tamanho já serve. O
/// fator mira o [tamanhoAlvoAssinatura] (o tamanho do PNG cresce
/// aproximadamente com a área) e nunca reduz a menos de 30%.
double? escalaDeReducao(int tamanhoBytes) {
  if (tamanhoBytes <= tamanhoMaximoAssinatura) return null;
  final fator = math.sqrt(tamanhoAlvoAssinatura / tamanhoBytes);
  return fator < 0.3 ? 0.3 : fator;
}

/// Assinatura em base64 -> bytes da imagem, ou `null` quando não há
/// assinatura ou ela não é uma imagem PNG/JPEG válida (base64 corrompido,
/// texto qualquer). Nunca lança nem registra o conteúdo (LGPD).
Uint8List? decodificarAssinatura(String? base64) {
  final texto = base64?.trim();
  if (texto == null || texto.isEmpty) return null;
  final Uint8List bytes;
  try {
    bytes = base64Decode(texto);
  } catch (_) {
    return null;
  }
  return _ehImagem(bytes) ? bytes : null;
}

bool _ehImagem(Uint8List b) {
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  final ehPng = b.length > png.length && _comeca(b, png);
  final ehJpeg = b.length > 3 && _comeca(b, const [0xFF, 0xD8, 0xFF]);
  return ehPng || ehJpeg;
}

bool _comeca(Uint8List b, List<int> prefixo) {
  for (var i = 0; i < prefixo.length; i++) {
    if (b[i] != prefixo[i]) return false;
  }
  return true;
}

/// A venda já tem uma assinatura utilizável. Se sim, coletar de novo é
/// "refazer" e pede confirmação, porque sobrescreve a anterior.
bool vendaAssinada(VendaModel venda) =>
    decodificarAssinatura(venda.assinaturaBase64) != null;
