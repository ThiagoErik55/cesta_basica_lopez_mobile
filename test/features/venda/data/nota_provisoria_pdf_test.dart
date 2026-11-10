import 'dart:convert';
import 'dart:typed_data';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/nota_provisoria_pdf.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/nota_provisoria.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG 1x1 válido.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

NotaProvisoria _nota({
  int itens = 3,
  bool parcelada = false,
  bool trocas = false,
  bool ajuste = false,
  String nome = 'Maria da Conceição Álvares',
  Uint8List? assinatura,
}) => NotaProvisoria(
  numeroNota: 2611091530,
  dataVenda: DateTime(2026, 11, 9, 14, 30),
  clienteNome: nome,
  cpfMascarado: '529.***.***-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua das Flores, 10, Centro',
  itens: [
    for (var i = 1; i <= itens; i++)
      ItemNota(
        codigo: 'P-$i',
        nome: 'Produto de teste número $i',
        quantidade: 2,
        precoUnitario: 10,
        subtotal: 20,
      ),
  ],
  trocas: trocas
      ? [
          TrocaNota(
            produtoOriginal: 'Arroz 5kg',
            produtoNovo: 'Arroz 2kg',
            quantidade: 1,
            data: DateTime(2026, 11, 12),
            diferenca: -10,
          ),
        ]
      : const [],
  subtotal: itens * 20.0,
  ajusteParcela: ajuste ? 5 : 0,
  total: itens * 20.0 + (ajuste ? 5 : 0),
  tipo: parcelada ? TipoVenda.parcelado : TipoVenda.aVista,
  forma: parcelada ? null : FormaPagamento.pix,
  parcelas: parcelada
      ? [
          for (var p = 1; p <= 4; p++)
            ParcelaNota(
              numero: p,
              vencimento: DateTime(2026, 12, p),
              valor: 15,
            ),
        ]
      : const [],
  emitidoEm: DateTime(2026, 11, 20, 16, 45),
  assinatura: assinatura,
);

int _paginas(Uint8List bytes) {
  final m = RegExp(r'/Count (\d+)').firstMatch(latin1.decode(bytes));
  return int.parse(m!.group(1)!);
}

void main() {
  test('gera bytes de PDF à vista', () async {
    final bytes = await gerarPdfNotaProvisoria(_nota());
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test(
    'poucos itens cabem em 1 página, inclusive parcelada com troca',
    () async {
      final bytes = await gerarPdfNotaProvisoria(
        _nota(parcelada: true, trocas: true, ajuste: true),
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      expect(_paginas(bytes), 1);
    },
  );

  test('60 itens passam para mais de 1 página', () async {
    final bytes = await gerarPdfNotaProvisoria(
      _nota(itens: 60, parcelada: true),
    );
    expect(_paginas(bytes), greaterThan(1));
  });

  test('aceita a imagem da assinatura', () async {
    final bytes = await gerarPdfNotaProvisoria(_nota(assinatura: _png));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(_paginas(bytes), 1);
  });

  test('não quebra com caracteres que a fonte padrão não desenha', () async {
    final bytes = await gerarPdfNotaProvisoria(_nota(nome: 'Zoë Łukasz 😀\nő'));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
