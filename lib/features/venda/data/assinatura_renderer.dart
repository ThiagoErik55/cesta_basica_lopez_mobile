import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../domain/assinatura.dart';

/// Espessura do traço, em pixels da tela.
const double espessuraTracoAssinatura = 3;

/// Folga em volta da assinatura ao recortar a imagem.
const double _margem = 16;

/// Caminho suave de um [traco]: curvas quadráticas passando pelos pontos
/// médios, em vez de segmentos retos entre as amostras do dedo. Usado na
/// tela e na imagem gravada, para os dois ficarem iguais.
Path caminhoDoTraco(List<Offset> traco) {
  final caminho = Path();
  if (traco.isEmpty) return caminho;
  caminho.moveTo(traco.first.dx, traco.first.dy);
  if (traco.length == 1) {
    caminho.lineTo(traco.first.dx + 0.01, traco.first.dy);
    return caminho;
  }
  for (var i = 1; i < traco.length - 1; i++) {
    final meio = (traco[i] + traco[i + 1]) / 2;
    caminho.quadraticBezierTo(traco[i].dx, traco[i].dy, meio.dx, meio.dy);
  }
  caminho.lineTo(traco.last.dx, traco.last.dy);
  return caminho;
}

/// Desenha [tracos] em [canvas], preto, com cantos arredondados.
void desenharTracos(
  Canvas canvas,
  List<List<Offset>> tracos, {
  double escala = 1,
}) {
  final tinta = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = espessuraTracoAssinatura * escala
    ..isAntiAlias = true;
  for (final traco in tracos) {
    canvas.drawPath(caminhoDoTraco(traco), tinta);
  }
}

/// Gera o PNG da assinatura: fundo branco, traço preto, recortado em
/// volta do desenho, com no máximo [larguraMaximaAssinatura] px de
/// largura. Se passar de [tamanhoMaximoAssinatura], reduz a escala e gera
/// de novo (até 3 vezes) para caber no documento do Firestore.
///
/// Os [tracos] devem ter [tracoSuficiente]; senão lança [ArgumentError].
Future<Uint8List> renderizarAssinatura(List<List<Offset>> tracos) async {
  if (!tracoSuficiente(tracos)) {
    throw ArgumentError('Assinatura sem traço suficiente.');
  }

  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final traco in tracos) {
    for (final p in traco) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  final origem = Offset(minX - _margem, minY - _margem);
  final largura = maxX - minX + 2 * _margem;
  final altura = maxY - minY + 2 * _margem;

  var escala = math.min(1.0, larguraMaximaAssinatura / largura);
  late Uint8List png;
  for (var tentativa = 0; tentativa < 4; tentativa++) {
    png = await _png(tracos, origem, largura, altura, escala);
    final reducao = escalaDeReducao(png.length);
    if (reducao == null) break;
    escala *= reducao;
  }
  return png;
}

Future<Uint8List> _png(
  List<List<Offset>> tracos,
  Offset origem,
  double largura,
  double altura,
  double escala,
) async {
  final w = math.max(1, (largura * escala).round());
  final h = math.max(1, (altura * escala).round());
  final gravador = PictureRecorder();
  final canvas = Canvas(gravador);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.scale(escala);
  canvas.translate(-origem.dx, -origem.dy);
  desenharTracos(canvas, tracos);
  final imagem = await gravador.endRecording().toImage(w, h);
  try {
    final dados = await imagem.toByteData(format: ImageByteFormat.png);
    return dados!.buffer.asUint8List();
  } finally {
    imagem.dispose();
  }
}
