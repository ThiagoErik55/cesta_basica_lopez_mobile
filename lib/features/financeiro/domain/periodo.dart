import 'dia.dart';

/// Tipos de período do painel financeiro (KAN-52).
enum TipoPeriodo { hoje, semana, mes, personalizado }

/// Maior intervalo aceito no período personalizado, em dias. Limita a
/// leitura do Firestore e deixa o gráfico legível.
const maximoDiasPersonalizado = 92;

/// Intervalo de dias de calendário local, com início inclusivo e fim
/// exclusivo (meia-noite do dia seguinte ao último dia), sem horário.
///
/// Conta de dias de calendário, nunca de 24 horas: assim a virada de dia
/// e de mês não depende de fuso nem de horário de verão.
class Periodo {
  const Periodo._(this.tipo, this.inicio, this.fim);

  /// Só o dia de [agora].
  factory Periodo.hoje(DateTime agora) => Periodo._(
    TipoPeriodo.hoje,
    inicioDoDia(agora),
    inicioDoDiaSeguinte(agora),
  );

  /// Semana de segunda a domingo que contém [agora].
  factory Periodo.semana(DateTime agora) {
    final segunda = DateTime(
      agora.year,
      agora.month,
      agora.day - (agora.weekday - DateTime.monday),
    );
    return Periodo._(
      TipoPeriodo.semana,
      segunda,
      DateTime(segunda.year, segunda.month, segunda.day + 7),
    );
  }

  /// Mês de calendário que contém [agora].
  factory Periodo.mes(DateTime agora) => Periodo._(
    TipoPeriodo.mes,
    DateTime(agora.year, agora.month),
    DateTime(agora.year, agora.month + 1),
  );

  /// De [de] até [ate], os dois dias incluídos. Se vierem invertidos,
  /// troca. Passa de [maximoDiasPersonalizado] dias, o fim é encurtado.
  factory Periodo.personalizado(DateTime de, DateTime ate) {
    var primeiro = inicioDoDia(de);
    var ultimo = inicioDoDia(ate);
    if (ultimo.isBefore(primeiro)) {
      (primeiro, ultimo) = (ultimo, primeiro);
    }
    var fim = inicioDoDiaSeguinte(ultimo);
    final limite = DateTime(
      primeiro.year,
      primeiro.month,
      primeiro.day + maximoDiasPersonalizado,
    );
    if (fim.isAfter(limite)) fim = limite;
    return Periodo._(TipoPeriodo.personalizado, primeiro, fim);
  }

  final TipoPeriodo tipo;

  /// Primeiro dia do período (00:00, inclusivo).
  final DateTime inicio;

  /// Dia seguinte ao último (00:00, exclusivo).
  final DateTime fim;

  /// Quantidade de dias de calendário.
  int get dias => diasEntre(inicio, fim);

  /// Último dia incluído no período.
  DateTime get ultimoDia => DateTime(fim.year, fim.month, fim.day - 1);

  /// Período imediatamente anterior, com a mesma quantidade de dias.
  Periodo get anterior => Periodo._(
    tipo,
    DateTime(inicio.year, inicio.month, inicio.day - dias),
    inicio,
  );

  /// `true` se [data] cai dentro do período.
  bool contem(DateTime data) => !data.isBefore(inicio) && data.isBefore(fim);

  /// Cada dia do período, em ordem.
  List<DateTime> get diasDoPeriodo => [
    for (var i = 0; i < dias; i++)
      DateTime(inicio.year, inicio.month, inicio.day + i),
  ];

  @override
  bool operator ==(Object other) =>
      other is Periodo &&
      other.tipo == tipo &&
      other.inicio == inicio &&
      other.fim == fim;

  @override
  int get hashCode => Object.hash(tipo, inicio, fim);
}

/// Dias de calendário entre as meias-noites [a] e [b] (b depois de a).
/// Passa por UTC para que mudança de horário não distorça a conta.
int diasEntre(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
