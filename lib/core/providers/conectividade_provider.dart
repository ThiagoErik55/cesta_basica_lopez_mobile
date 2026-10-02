import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` quando há alguma interface de rede ativa.
///
/// `onConnectivityChanged` só emite quando a conexão muda — na web, por
/// exemplo, nada chega enquanto ela continua igual, e o badge ficava em
/// "OFFLINE" com a internet funcionando. Por isso o estado atual é
/// consultado primeiro, com `checkConnectivity`, e só depois as mudanças
/// são acompanhadas.
///
/// Indica rede ativa, não acesso garantido à internet (ex. Wi-Fi sem
/// saída) — o Firestore continua tratando a falta de conexão sozinho.
final conectividadeProvider = StreamProvider<bool>((ref) async* {
  final conectividade = Connectivity();
  yield _conectado(await conectividade.checkConnectivity());
  yield* conectividade.onConnectivityChanged.map(_conectado);
});

bool _conectado(List<ConnectivityResult> resultados) =>
    !resultados.contains(ConnectivityResult.none);
