import 'dart:convert';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/comprovante_pdf.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/comprovante_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

ComprovantePagamento _comprovante({
  bool quitada = false,
  String? observacao,
  String nome = 'Maria da Conceição Álvares',
}) => ComprovantePagamento(
  numero: '2611091530-P2-1',
  clienteNome: nome,
  cpfMascarado: '529.***.***-25',
  numeroNota: 2611091530,
  numeroParcela: 2,
  totalParcelas: 5,
  dataPagamento: DateTime(2026, 11, 15),
  valorPago: 123.45,
  forma: FormaPagamento.valeAlimentacao,
  observacao: observacao,
  saldoRestanteParcela: quitada ? 0 : 76.55,
  saldoEmAbertoVenda: 276.55,
  parcelaQuitada: quitada,
  emitidoEm: DateTime(2026, 11, 20, 16, 45),
);

void main() {
  test('gera bytes de PDF não vazios', () async {
    final bytes = await gerarPdfComprovante(_comprovante());
    expect(bytes, isNotEmpty);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('gera com parcela quitada e com observação', () async {
    final bytes = await gerarPdfComprovante(
      _comprovante(quitada: true, observacao: 'Pago em mãos, com troco.'),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('cabe em uma página, mesmo com observação longa', () async {
    final bytes = await gerarPdfComprovante(
      _comprovante(observacao: 'Observação muito longa. ' * 12),
    );
    // Uma única página: o catálogo de páginas conta /Count 1.
    final texto = latin1.decode(bytes);
    expect(RegExp(r'/Count 1\b').hasMatch(texto), isTrue);
  });

  test('não quebra com caracteres que a fonte padrão não desenha', () async {
    final bytes = await gerarPdfComprovante(
      _comprovante(nome: 'Zoë Łukasz 😀', observacao: 'Pago\ncom troco ő'),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
