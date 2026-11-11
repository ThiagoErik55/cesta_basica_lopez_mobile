import 'dart:async';

/// Tempo de espera pela primeira leitura antes de cair no cache local.
const esperaPadraoAntesDoCache = Duration(seconds: 8);

/// Repassa [origem] e, se ela não emitir nada em [espera], emite o que
/// [cache] devolver (sem perder as emissões que chegarem depois). Cache
/// vazio vira [TimeoutException], para a tela mostrar erro em vez de uma
/// lista vazia enganosa. Erros da [origem] são repassados.
Stream<List<T>> comFallbackDeCache<T>(
  Stream<List<T>> origem,
  Future<List<T>> Function() cache, {
  Duration espera = esperaPadraoAntesDoCache,
}) {
  late final StreamController<List<T>> controlador;
  StreamSubscription<List<T>>? assinatura;
  Timer? relogio;
  var recebeu = false;

  controlador = StreamController<List<T>>(
    onListen: () {
      assinatura = origem.listen(
        (dados) {
          recebeu = true;
          relogio?.cancel();
          controlador.add(dados);
        },
        onError: (Object e, StackTrace s) {
          recebeu = true;
          relogio?.cancel();
          controlador.addError(e, s);
        },
        onDone: () {
          relogio?.cancel();
          controlador.close();
        },
      );
      relogio = Timer(espera, () async {
        if (recebeu || controlador.isClosed) return;
        try {
          final doCache = await cache();
          if (recebeu || controlador.isClosed) return;
          if (doCache.isEmpty) {
            controlador.addError(
              TimeoutException('Sem resposta do servidor nem dados em cache.'),
            );
          } else {
            controlador.add(doCache);
          }
        } catch (e, s) {
          if (!recebeu && !controlador.isClosed) controlador.addError(e, s);
        }
      });
    },
    onCancel: () {
      relogio?.cancel();
      return assinatura?.cancel();
    },
  );
  return controlador.stream;
}
