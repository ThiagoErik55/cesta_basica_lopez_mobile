abstract class EntidadeBase {
  String get id;
  DateTime get updatedAt;
  bool get deleted;

  Map<String, dynamic> toMap();
}
