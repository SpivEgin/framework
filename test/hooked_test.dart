import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:http/http.dart' as http;
import 'package:json_god/json_god.dart' as god;
import 'package:test/test.dart';
import 'common.dart';

main() {
  Map headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  Angel app;
  HttpServer server;
  String url;
  http.Client client;
  HookedService Todos;

  setUp(() async {
    app = new Angel();
    client = new http.Client();
    app.use('/todos', new TypedService<Todo>(new MapService()));
    app.use('/books', new BookService());
    Todos = app.service("todos");

    Todos.beforeAllStream().listen((e) {
      print('Fired ${e.eventName}! Data: ${e.data}; Params: ${e.params}');
    });

    app.fatalErrorStream.listen((e) => throw e.error);

    server = await app.startServer();
    url = "http://${app.httpServer.address.host}:${app.httpServer.port}";
  });

  tearDown(() async {
    await server.close(force: true);
    app = null;
    url = null;
    client.close();
    client = null;
    Todos = null;
  });

  test("listen before and after", () async {
    int count = 0;

    Todos
      ..beforeIndexed.listen((_) {
        count++;
      })
      ..afterIndexed.listen((_) {
        count++;
      });

    var response = await client.get("$url/todos");
    print(response.body);
    expect(count, equals(2));
  });

  test("cancel before", () async {
    Todos.beforeCreated
      ..listen((HookedServiceEvent event) {
        event.cancel({"hello": "hooked world"});
      })
      ..listen((HookedServiceEvent event) {
        event.cancel({"this_hook": "should never run"});
      });

    var response = await client.post("$url/todos",
        body: god.serialize({"arbitrary": "data"}), headers: headers);
    print(response.body);
    Map result = god.deserialize(response.body);
    expect(result["hello"], equals("hooked world"));
  });

  test("cancel after", () async {
    Todos.afterIndexed
      ..listen((HookedServiceEvent event) async {
        // Hooks can be Futures ;)
        event.cancel([
          {"angel": "framework"}
        ]);
      })
      ..listen((HookedServiceEvent event) {
        event.cancel({"this_hook": "should never run either"});
      });

    var response = await client.get("$url/todos");
    print(response.body);
    List result = god.deserialize(response.body);
    expect(result[0]["angel"], equals("framework"));
  });

  test('metadata', () async {
    final service = new HookedService(new IncrementService())..addHooks();
    expect(service.inner, isNot(new isInstanceOf<MapService>()));
    IncrementService.TIMES = 0;
    await service.index();
    expect(IncrementService.TIMES, equals(2));
  });

  test('inject request + response', () async {
    HookedService books = app.service('books');

    books.beforeIndexed.listen((e) {
      expect([e.request, e.response], everyElement(isNotNull));
      print('Indexing books at path: ${e.request.path}');
    });

    var response = await client.get('$url/books');
    print(response.body);

    var result = god.deserialize(response.body);
    expect(result, isList);
    expect(result, isNotEmpty);
    expect(result[0], equals({'foo': 'bar'}));
  });
}
