import '../../venda/data/venda_model.dart';
import '../data/despesa_model.dart';
import 'agregacao_financeira.dart';

/// Resumo financeiro de um dia do vendedor (RF29, KAN-51).
///
/// Segue a apuração do modelo lógico (seção 5):
///
/// ```
/// lucro bruto = Σ quantidade × (precoUnitario − custoUnitario)
/// saldo do dia = lucro bruto − Σ despesas do dia
/// ```
///
/// O faturamento (total vendido) também é exibido, mas o saldo parte do
/// lucro: descontar as despesas do valor vendido ignoraria o que foi
/// pago pelos produtos.
class ResumoDia {
  const ResumoDia({
    required this.pedidos,
    required this.unidades,
    required this.faturamento,
    required this.lucroBruto,
    required this.despesas,
    required this.quantidadeDespesas,
    required this.itensSemCusto,
  });

  /// Monta o resumo a partir das vendas e despesas do dia (já filtradas
  /// pelo vendedor e pelo dia).
  factory ResumoDia.calcular({
    required Iterable<VendaModel> vendas,
    required Iterable<DespesaModel> despesas,
  }) {
    // Uma só fonte para faturamento, custo e lucro (agregacao_financeira).
    final t = calcularTotais(vendas: vendas, despesas: despesas);
    return ResumoDia(
      pedidos: t.vendas,
      unidades: t.unidades,
      faturamento: t.faturamento / 100,
      lucroBruto: t.lucroBruto / 100,
      despesas: t.despesas / 100,
      quantidadeDespesas: t.quantidadeDespesas,
      itensSemCusto: t.itensSemCusto,
    );
  }

  /// Vendas registradas no dia.
  final int pedidos;

  /// Unidades vendidas (cestas e demais produtos).
  final int unidades;

  /// Total vendido, à vista e parcelado.
  final double faturamento;

  /// Faturamento menos o custo dos produtos vendidos.
  final double lucroBruto;

  /// Total das despesas do dia.
  final double despesas;
  final int quantidadeDespesas;

  /// Itens vendidos sem custo registrado (custo zero): o lucro desses
  /// itens fica igual ao preço, então o saldo sai maior que o real.
  final int itensSemCusto;

  /// Custo dos produtos vendidos.
  double get custoProdutos => _centavos(faturamento - lucroBruto);

  /// Saldo do dia: lucro bruto menos despesas. Pode ser negativo.
  double get saldo => _centavos(lucroBruto - despesas);

  bool get vazio => pedidos == 0 && quantidadeDespesas == 0;
}

/// Arredonda para centavos, evitando sobras de ponto flutuante como
/// 0.30000000000000004.
double _centavos(double valor) => (valor * 100).roundToDouble() / 100;
