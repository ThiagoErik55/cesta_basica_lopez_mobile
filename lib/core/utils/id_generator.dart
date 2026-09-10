import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String gerarId() => _uuid.v4();