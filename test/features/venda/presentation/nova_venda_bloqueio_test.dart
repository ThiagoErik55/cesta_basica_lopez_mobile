import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/regra_bloqueio.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/carrinho.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/nova_venda_providers.dart';
import 'package:flutter_test/flutter_test.dart';

final _hoje = DateTime.now();

ClienteModel _cliente({
  bool bloqueado = false,
  double valorEmAberto = 0,
  double limiteCredito = 0,
  int? diasEmAtraso,
}) => ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria',
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua A',
  bloqueado: bloqueado,
  valorEmAberto: valorEmAberto,
  limiteCredito: limiteCredito,
  proximoVencimento: diasEmAtraso == null
      ? null
      : DateTime(_hoje.year, _hoje.month, _hoje.day - diasEmAtraso),
  updatedAt: _hoje,
);

final _produto = ProdutoModel(
  id: 'p1',
  codigo: 'P1',
  nome: 'Cesta',
  marca: 'M',
  categoria: 'Cestas',
  preco: 100,
  estoqueAtual: 10,
  updatedAt: _hoje,
);

NovaVendaState _venda(
  ClienteModel cliente, {
  required OpcaoPagamento pagamento,
  RegraBloqueio regra = regraBloqueioPadrao,
  List<ParcelaModel>? parcelasPendentes,
}) => NovaVendaState(
  cliente: cliente,
  itens: {'p1': ItemCarrinho(produto: _produto, quantidade: 1)},
  pagamento: pagamento,
  primeiroVencimento: DateTime(_hoje.year, _hoje.month, _hoje.day + 30),
  regra: regra,
  parcelasPendentes: parcelasPendentes,
);

const _aVista = PagamentoAVista(FormaPagamento.dinheiro);
const _parcelado = PagamentoParcelado();

void main() {
  group('nova venda com cliente bloqueado', () {
    test('bloqueio manual impede a venda à vista e a parcelada', () {
      final c = _cliente(bloqueado: true);
      expect(
        _venda(c, pagamento: _aVista).impedimento,
        contains('manualmente'),
      );
      expect(
        _venda(c, pagamento: _parcelado).impedimento,
        contains('manualmente'),
      );
    });

    test('bloqueio por atraso libera a venda à vista', () {
      final c = _cliente(valorEmAberto: 80, diasEmAtraso: 23);
      expect(_venda(c, pagamento: _aVista).impedimento, isNull);
    });

    test('bloqueio por atraso impede a parcelada, com o motivo', () {
      final c = _cliente(valorEmAberto: 80, diasEmAtraso: 23);
      final impedimento = _venda(c, pagamento: _parcelado).impedimento;
      expect(impedimento, contains('23 dias'));
    });

    test('atraso abaixo da tolerância não impede o parcelado', () {
      final c = _cliente(valorEmAberto: 80, diasEmAtraso: 10);
      expect(_venda(c, pagamento: _parcelado).impedimento, isNull);
    });

    test('limite estourado impede só a parcelada', () {
      final c = _cliente(valorEmAberto: 150, limiteCredito: 200);
      final parcelado = _venda(c, pagamento: _parcelado).impedimento;
      expect(parcelado, contains('Limite de crédito excedido'));
      expect(_venda(c, pagamento: _aVista).impedimento, isNull);
    });

    test('limite 0 não impede nada', () {
      final c = _cliente(valorEmAberto: 5000);
      expect(_venda(c, pagamento: _parcelado).impedimento, isNull);
    });

    test(
      'desbloqueia quando as parcelas atrasadas deixam de estar pendentes',
      () {
        final c = _cliente(valorEmAberto: 80, diasEmAtraso: 23);
        final atrasada = ParcelaModel(
          id: 'a',
          vendaId: 'v',
          numero: 1,
          valor: 80,
          vencimento: DateTime(_hoje.year, _hoje.month, _hoje.day - 23),
          updatedAt: _hoje,
        );
        expect(
          _venda(
            c,
            pagamento: _parcelado,
            parcelasPendentes: [atrasada],
          ).impedimento,
          isNotNull,
        );
        expect(
          _venda(
            c,
            pagamento: _parcelado,
            parcelasPendentes: const [],
          ).impedimento,
          isNull,
        );
      },
    );
  });
}
