import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:angel_framework/angel_framework.dart';

main() async {
  int x = 0;
  var c = new Completer();
  var exit = new ReceivePort();
  List<Isolate> isolates = [];

  exit.listen((_) {
    if (++x >= 50) {
      c.complete();
    }
  });

  for (int i = 0; i < 50; i++) {
    var isolate = await Isolate.spawn(serverMain, null);
    isolates.add(isolate);
    print('Spawned isolate #${i + 1}...');

    isolate.addOnExitListener(exit.sendPort);
  }

  print('Angel listening at http://localhost:3000');
  await c.future;
}

serverMain(_) async {
  var app = new Angel.custom(startShared); // Run a cluster

  app.get('/', {
    "foo": "bar",
    "one": [2, "three"],
    "bar": {"baz": "quux"}
  });

  // Performance tuning
  app
    ..lazyParseBodies = true
    ..injectSerializer(JSON.encode);

  app.fatalErrorStream.listen((e) {
    print(e.error);
    print(e.stack);
  });

  await app.startServer(InternetAddress.LOOPBACK_IP_V4, 3000);
}
