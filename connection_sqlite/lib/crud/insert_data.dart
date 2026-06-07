import 'package:connection_sqlite/main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

// Referência ao nó "entregas" no Realtime Database.
final DatabaseReference entregasRef =
    FirebaseDatabase.instance.ref('entregas');

/// Gera uma chave única para uma nova entrega. Funciona inclusive offline,
/// pois o próprio SDK do Firebase cria a chave localmente.
String novoIdEntrega() =>
    entregasRef.push().key ??
    DateTime.now().microsecondsSinceEpoch.toString();

/// Insere a entrega nos DOIS bancos: primeiro no SQLite (local) e depois no
/// Realtime Database. Se o Firebase estiver inacessível, os dados continuam
/// salvos localmente e a tela segue funcionando.
Future<void> inserirEntrega(Entrega e) async {
  await DatabaseHelper.instance.upsertEntrega(e);
  try {
    await entregasRef
        .child(e.id)
        .set(e.toMap())
        .timeout(const Duration(seconds: 5));
  } catch (err) {
    debugPrint('Sem acesso ao Firebase ao inserir: $err');
  }
}
