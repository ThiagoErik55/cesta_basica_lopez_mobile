import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/resumo_dia.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _dia = DateTime(2026, 11, 18, 10);

ItemVenda _item({
  required int quantidade,
  required double preco,
  required double custo,
}) => ItemVenda(
  id: 'i$quantidade$preco',
  produtoId: 'p',
  nome: 'Produto',
  quantidade: quantidade,
  precoUnitario: preco,
  custoUnitario: custo,
);

VendaModel _venda(String id, List<ItemVenda> itens) => VendaModel(
  id: id,
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: _dia,
  itens: itens,
  valorTotal: itens.fold<double>(0, (s, i) => s + i.subtotal),
  tipo: TipoVenda.aVista,
  updatedAt: _dia,
);

DespesaModel _despesa(double valor) => DespesaModel(
  id: '$valor',
  vendedorUid: 'u1',
  descricao: 'Combustível',
  valor: valor,
  data: _dia,
  updatedAt: _dia,
);

void main() {
  test('saldo é o lucro das vendas menos as despesas', () {
    final r = ResumoDia.calcular(
      vendas: [
        // 2 × (130 − 90) = 80 de lucro
        _venda('v1', [_item(quantidade: 2, preco: 130, custo: 90)]),
        // 3 × (10 − 6) = 12 de lucro
        _venda('v2', [_item(quantidade: 3, preco: 10, custo: 6)]),
      ],
      despesas: [_despesa(30), _despesa(12.5)],
    );

    expect(r.pedidos, 2);
    expect(r.unidades, 5);
    expect(r.faturamento, 290);
    expect(r.lucroBruto, 92);
    expect(r.custoProdutos, 198);
    expect(r.despesas, 42.5);
    expect(r.quantidadeDespesas, 2);
    expect(r.saldo, 49.5);
  });

  test('saldo pode ficar negativo quando as despesas passam do lucro', () {
    final r = ResumoDia.calcular(
      vendas: [
        _venda('v1', [_item(quantidade: 1, preco: 20, custo: 15)]),
      ],
      despesas: [_despesa(50)],
    );
    expect(r.saldo, -45);
  });

  test('dia sem vendas nem despesas fica zerado e vazio', () {
    final r = ResumoDia.calcular(vendas: const [], despesas: const []);
    expect(r.vazio, isTrue);
    expect(r.saldo, 0);
    expect(r.faturamento, 0);
  });

  test('conta os itens vendidos sem custo cadastrado', () {
    final itensMistos = [
      _item(quantidade: 1, preco: 20, custo: 0),
      _item(quantidade: 2, preco: 8, custo: 5),
    ];
    final r = ResumoDia.calcular(
      vendas: [
        _venda('v1', itensMistos),
      ],
      despesas: const [],
    );
    expect(r.itensSemCusto, 1);
  });

  test('arredonda os totais em centavos', () {
    final r = ResumoDia.calcular(
      vendas: [
        _venda('v1', [_item(quantidade: 3, preco: 0.1, custo: 0)]),
      ],
      despesas: [_despesa(0.1), _despesa(0.2)],
    );
    expect(r.faturamento, 0.3);
    expect(r.despesas, 0.3);
    expect(r.saldo, 0);
  });
}