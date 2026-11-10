import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/utils/formatadores.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/comprovante_pagamento.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/mensagens_whatsapp.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/nota_provisoria.dart';
import 'package:flutter_test/flutter_test.dart';

ComprovantePagamento _comprovante({String nome = 'Maria da Conceição'}) =>
    ComprovantePagamento(
      numero: '2611091530-P2-1',
      clienteNome: nome,
      cpfMascarado: '529.***.***-25',
      telefone: '(45) 99999-0001',
      numeroNota: 2611091530,
      numeroParcela: 2,
      totalParcelas: 5,
      dataPagamento: DateTime(2026, 11, 15),
      valorPago: 123.45,
      forma: FormaPagamento.pix,
      observacao: null,
      saldoRestanteParcela: 76.55,
      saldoEmAbertoVenda: 276.55,
      parcelaQuitada: false,
      emitidoEm: DateTime(2026, 11, 20),
    );

NotaProvisoria _nota({String nome = 'Maria da Conceição'}) => NotaProvisoria(
  numeroNota: 2611091530,
  dataVenda: DateTime(2026, 11, 9),
  clienteNome: nome,
  cpfMascarado: '529.***.***-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua das Flores, 10, Centro',
  itens: const [],
  trocas: const [],
  subtotal: 150,
  ajusteParcela: 0,
  total: 150,
  tipo: TipoVenda.aVista,
  forma: FormaPagamento.pix,
  parcelas: const [],
  emitidoEm: DateTime(2026, 11, 20),
);

void main() {
  test('mensagem do comprovante', () {
    expect(
      mensagemComprovante(_comprovante()),
      'Olá, Maria! Segue o comprovante do seu pagamento de '
      '${formatarMoeda(123.45)} referente à nota 2611091530, parcela 2/5, '
      'em 15/11/2026. Obrigado! Cesta Básica Lopez',
    );
  });

  test('mensagem da nota', () {
    expect(
      mensagemNota(_nota()),
      'Olá, Maria! Segue a nota provisória 2611091530 da sua compra de '
      '09/11/2026, no valor de ${formatarMoeda(150)}. Obrigado! '
      'Cesta Básica Lopez',
    );
  });

  test('cliente com um só nome', () {
    expect(
      mensagemComprovante(_comprovante(nome: 'Cher')),
      startsWith('Olá, Cher! '),
    );
    expect(mensagemNota(_nota(nome: 'Cher')), startsWith('Olá, Cher! '));
  });

  test('sem nome: saudação genérica', () {
    expect(mensagemNota(_nota(nome: '  ')), startsWith('Olá! Segue'));
  });

  test('sem CPF, endereço, telefone nem saldo em aberto', () {
    final textos = [mensagemComprovante(_comprovante()), mensagemNota(_nota())];
    for (final t in textos) {
      expect(t, isNot(contains('529')));
      expect(t, isNot(contains('***')));
      expect(t, isNot(contains('Rua das Flores')));
      expect(t, isNot(contains('99999')));
      expect(t, isNot(contains(formatarMoeda(276.55))));
      expect(t, isNot(contains(formatarMoeda(76.55))));
      expect(t, isNot(contains('Conceição')));
    }
  });
}
