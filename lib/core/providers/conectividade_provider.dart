import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conectividadeProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((resultados) {
    return !resultados.contains(ConnectivityResult.none);
  });
});