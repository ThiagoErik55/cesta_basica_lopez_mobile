abstract class BaseRepository<T> {
  Future<void> salvar(T item);
  Future<T?> buscarPorId(String id);
  Stream<List<T>> observarTodos();
  Future<void> remover(String id);
}