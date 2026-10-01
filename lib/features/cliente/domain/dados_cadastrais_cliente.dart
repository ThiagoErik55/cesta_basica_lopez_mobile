/// Dados cadastrais preenchidos no formulário de cliente — os únicos
/// campos do cliente editáveis pelo vendedor (score, limite de crédito e
/// bloqueado são definidos em outros fluxos).
class DadosCadastraisCliente {
  const DadosCadastraisCliente({
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.endereco,
    this.rotaId,
  });

  final String nome;
  final String cpf;
  final String telefone;
  final String endereco;
  final String? rotaId;
}
