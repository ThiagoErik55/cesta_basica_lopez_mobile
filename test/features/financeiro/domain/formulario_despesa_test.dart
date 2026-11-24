import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/formulario_despesa.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 18, 15);

ResultadoDespesa _avaliar({
  String descricao = 'Combustível',
  double? valor = 120,
  DateTime? data,
}) => avaliarDespesa(
  descricao: descricao,
  valor: valor,
  data: data ?? _agora,
  agora: _agora,
);

void main() {
  test('despesa preenchida é válida e tira espaços da descrição', () {
    final r = _avaliar(descricao: '  Combustível  ');
    expect(r.ok, isTrue);
    expect(r.descricao, 'Combustível');
  });

  test('descrição é obrigatória', () {
    expect(_avaliar(descricao: '   ').erroDescricao, isNotNull);
  });

  test('descrição longa demais é recusada', () {
    final r = _avaliar(descricao: 'a' * (limiteDescricaoDespesa + 1));
    expect(r.erroDescricao, isNotNull);
  });

  test('valor vazio, zero ou negativo é recusado', () {
    expect(_avaliar(valor: null).erroValor, isNotNull);
    expect(_avaliar(valor: 0).erroValor, isNotNull);
    expect(_avaliar(valor: -5).erroValor, isNotNull);
  });

  test('data futura é recusada; dias anteriores e hoje são aceitos', () {
    expect(_avaliar(data: DateTime(2026, 11, 19)).erroData, isNotNull);
    expect(_avaliar(data: DateTime(2026, 11, 18, 23, 59)).erroData, isNull);
    expect(_avaliar(data: DateTime(2026, 11, 10)).erroData, isNull);
  });

  test('totalDespesas soma os valores', () {
    DespesaModel d(double valor) => DespesaModel(
      id: '$valor',
      vendedorUid: 'u1',
      descricao: 'x',
      valor: valor,
      data: _agora,
      updatedAt: _agora,
    );
    expect(totalDespesas([d(100), d(35.5), d(14.5)]), 150);
    expect(totalDespesas(const []), 0);
  });
}