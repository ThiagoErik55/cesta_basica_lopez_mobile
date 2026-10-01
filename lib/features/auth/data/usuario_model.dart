import '../../../core/domain/enums.dart';

// O documento em usuarios/{uid} deve gravar o campo uid explicitamente no
// corpo (não depender do doc.id) — fromMap lê o valor a partir do mapa.
class UsuarioModel {
  final String uid;
  final String nome;
  final String email;
  final LinhaAtendimento linhaAtendimento;
  final bool ativo;

  const UsuarioModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.linhaAtendimento,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nome': nome,
    'email': email,
    'linhaAtendimento': linhaAtendimento.name,
    'ativo': ativo,
  };

  factory UsuarioModel.fromMap(Map<String, dynamic> map) => UsuarioModel(
    uid: map['uid'] as String,
    nome: map['nome'] as String? ?? '',
    email: map['email'] as String? ?? '',
    linhaAtendimento: lerEnum(
      LinhaAtendimento.values,
      map['linhaAtendimento'],
      LinhaAtendimento.toledo,
    ),
    ativo: map['ativo'] as bool? ?? true,
  );
}
