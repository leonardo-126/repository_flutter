import 'package:connection_sqlite/crud/insert_data.dart' show entregasRef;
import 'package:connection_sqlite/main.dart';
import 'package:flutter/foundation.dart';

/// Atualiza a entrega nos DOIS bancos (SQLite + Realtime Database).
/// Usa o mesmo id como chave nos dois, garantindo a sincronia entre eles.
Future<void> atualizarEntrega(Entrega e) async {
  await DatabaseHelper.instance.upsertEntrega(e);
  try {
    await entregasRef
        .child(e.id)
        .update(e.toMap())
        .timeout(const Duration(seconds: 5));
  } catch (err) {
    debugPrint('Sem acesso ao Firebase ao atualizar: $err');
  }
}

/// Exclui a entrega nos DOIS bancos. Se o Firebase estiver indisponível,
/// a exclusão local ainda acontece.
Future<void> excluirEntrega(String id) async {
  await DatabaseHelper.instance.deleteEntrega(id);
  try {
    await entregasRef
        .child(id)
        .remove()
        .timeout(const Duration(seconds: 5));
  } catch (err) {
    debugPrint('Sem acesso ao Firebase ao excluir: $err');
  }
}
