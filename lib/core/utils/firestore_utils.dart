import 'package:cloud_firestore/cloud_firestore.dart';

DateTime lerData(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is String) return DateTime.parse(valor);
  return DateTime.now();
}

DateTime? lerDataOpcional(dynamic valor) =>
    valor == null ? null : lerData(valor);

double lerDouble(dynamic valor) => valor is num ? valor.toDouble() : 0;

int lerInt(dynamic valor) => valor is num ? valor.toInt() : 0;

double? lerDoubleOpcional(dynamic valor) =>
    valor == null ? null : lerDouble(valor);

int? lerIntOpcional(dynamic valor) => valor == null ? null : lerInt(valor);
