/// Meia-noite do dia de [data] (início do dia, horário local).
DateTime inicioDoDia(DateTime data) =>
    DateTime(data.year, data.month, data.day);

/// Meia-noite do dia seguinte a [data]: fim exclusivo do dia.
DateTime inicioDoDiaSeguinte(DateTime data) =>
    DateTime(data.year, data.month, data.day + 1);

/// `true` se [a] e [b] caem no mesmo dia.
bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;