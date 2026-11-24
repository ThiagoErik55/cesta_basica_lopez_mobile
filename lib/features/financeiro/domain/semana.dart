import 'dia.dart';
import 'periodo.dart';

/// Navegação por semana de segunda a domingo (KAN-53). Tudo em dia de
/// calendário local, com fim exclusivo, como o [Periodo] da KAN-52.

/// Semana (segunda a domingo) que contém [data]. Data futura vira a
/// semana corrente: o relatório não olha além de [agora].
Periodo semanaDaData(DateTime data, DateTime agora) =>
    inicioDoDia(data).isAfter(inicioDoDia(agora))
    ? Periodo.semana(agora)
    : Periodo.semana(data);

/// Semana imediatamente anterior a [semana].
Periodo semanaAnteriorA(Periodo semana) => Periodo.semana(
  DateTime(semana.inicio.year, semana.inicio.month, semana.inicio.day - 7),
);

/// Semana imediatamente seguinte a [semana]; `null` se já é a corrente
/// (não existe semana futura além dela).
Periodo? semanaSeguinteA(Periodo semana, DateTime agora) {
  final proxima = Periodo.semana(
    DateTime(semana.inicio.year, semana.inicio.month, semana.inicio.day + 7),
  );
  return proxima.inicio.isAfter(inicioDoDia(agora)) ? null : proxima;
}

/// `true` se [semana] é a que contém [agora].
bool ehSemanaCorrente(Periodo semana, DateTime agora) =>
    semana.contem(inicioDoDia(agora));
