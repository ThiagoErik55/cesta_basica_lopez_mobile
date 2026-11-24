import '../data/despesa_model.dart';
import 'dia.dart';

/// Descrições sugeridas no formulário de despesa (KAN-50). Tocar em uma
/// preenche o campo; o vendedor pode escrever qualquer outra.
const sugestoesDespesa = [
  'Combustível',
  'Alimentação',
  'Manutenção do veículo',
  'Pedágio',
];

/// Limite de caracteres da descrição.
const limiteDescricaoDespesa = 80;

/// Resultado da validação do formulário de despesa. Os erros são `null`
/// quando o campo está certo.
class ResultadoDespesa {
  const ResultadoDespesa({
    required this.descricao,
    required this.valor,
    this.erroDescricao,
    this.erroValor,
    this.erroData,
  });

  /// Descrição já sem espaços nas pontas.
  final String descricao;
  final double? valor;
  final String? erroDescricao;
  final String? erroValor;
  final String? erroData;

  bool get ok => erroDescricao == null && erroValor == null && erroData == null;
}

/// Valida a despesa (KAN-50): descrição obrigatória, valor maior que
/// zero e data que não seja futura (uma despesa já aconteceu).
ResultadoDespesa avaliarDespesa({
  required String descricao,
  required double? valor,
  required DateTime data,
  required DateTime agora,
}) {
  final texto = descricao.trim();

  String? erroDescricao;
  if (texto.isEmpty) {
    erroDescricao = 'Informe a descrição.';
  } else if (texto.length > limiteDescricaoDespesa) {
    erroDescricao = 'Use no máximo $limiteDescricaoDespesa caracteres.';
  }

  String? erroValor;
  if (valor == null) {
    erroValor = 'Informe o valor.';
  } else if (valor <= 0) {
    erroValor = 'O valor deve ser maior que zero.';
  }

  final erroData = inicioDoDia(data).isAfter(inicioDoDia(agora))
      ? 'A data não pode ser futura.'
      : null;

  return ResultadoDespesa(
    descricao: texto,
    valor: valor,
    erroDescricao: erroDescricao,
    erroValor: erroValor,
    erroData: erroData,
  );
}

/// Soma dos valores das despesas.
double totalDespesas(Iterable<DespesaModel> despesas) =>
    despesas.fold<double>(0, (soma, d) => soma + d.valor);