import 'dart:async';

import 'package:connection_sqlite/crud/insert_data.dart' show entregasRef;
import 'package:connection_sqlite/main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Lê as entregas em tempo real, coordenando os DOIS bancos:
/// 1) emite primeiro o cache local (SQLite), para a tela nunca ficar vazia;
/// 2) acompanha o estado da conexão pelo nó ".info/connected";
/// 3) escuta as entregas no Firebase em tempo real e espelha cada
///    atualização no SQLite;
/// 4) se o acesso ao Firebase falhar, volta a exibir os dados do SQLite.
Stream<EntregaSnapshot> observarEntregas() {
  late final StreamController<EntregaSnapshot> ctrl;
  StreamSubscription<DatabaseEvent>? dadosSub;
  StreamSubscription<DatabaseEvent>? conexaoSub;
  var online = false;
  var atuais = <Entrega>[];

  Future<void> emitirLocal() async {
    atuais = await DatabaseHelper.instance.getEntregas();
    if (!ctrl.isClosed) ctrl.add(EntregaSnapshot(atuais, online: online));
  }

  ctrl = StreamController<EntregaSnapshot>(
    onListen: () async {
      // 1) Mostra imediatamente o que existe no cache local.
      await emitirLocal();

      // 2) Acompanha o estado da conexão com o Firebase.
      conexaoSub = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen((event) {
        online = (event.snapshot.value as bool?) ?? false;
        if (!ctrl.isClosed) {
          ctrl.add(EntregaSnapshot(atuais, online: online));
        }
      });

      // 3) Escuta as entregas em tempo real e espelha no SQLite.
      dadosSub = entregasRef.onValue.listen((event) async {
        final lista = <Entrega>[];
        for (final filho in event.snapshot.children) {
          final map = Map<String, dynamic>.from(filho.value as Map);
          map['id'] = filho.key;
          lista.add(Entrega.fromMap(map));
        }
        lista.sort((a, b) => b.dataEntrega.compareTo(a.dataEntrega));
        atuais = lista;
        await DatabaseHelper.instance.replaceAll(lista); // espelha offline
        if (!ctrl.isClosed) {
          ctrl.add(EntregaSnapshot(atuais, online: online));
        }
      }, onError: (Object err) async {
        // Falha de acesso ao Firebase: volta para o cache local.
        debugPrint('Erro ao ler do Firebase, usando SQLite: $err');
        online = false;
        await emitirLocal();
      });
    },
    onCancel: () async {
      await dadosSub?.cancel();
      await conexaoSub?.cancel();
    },
  );

  return ctrl.stream;
}
