import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'common.dart';

@Expose("/todos", middleware: const ["foo"])
class TodoController extends Controller {
  List<Todo> todos = [new Todo(text: "Hello", over: "world")];

  @Expose("/:id", middleware: const ["bar"])
  Future<Todo> fetchTodo(
      String id, RequestContext req, ResponseContext res) async {
    expect(req, isNotNull);
    expect(res, isNotNull);
    return todos[int.parse(id)];
  }

  @Expose("/namedRoute/:foo", as: "foo")
  Future<String> someRandomRoute(
      RequestContext req, ResponseContext res) async {
    return "${req.params['foo']}!";
  }
}

main() {
  Angel app;
  HttpServer server;
  http.Client client = new http.Client();
  String url;

  setUp(() async {
    app = new Angel(debug: true);
    app.registerMiddleware("foo", (req, res) async => res.write("Hello, "));
    app.registerMiddleware("bar", (req, res) async => res.write("world!"));
    app.get(
        "/redirect",
        (req, ResponseContext res) async =>
            res.redirectToAction("TodoController@foo", {"foo": "world"}));
    await app.configure(new TodoController());

    print(app.controllers);
    app.dumpTree();

    server = await app.startServer();
    url = 'http://${server.address.address}:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
    app = null;
    url = null;
  });

  test("middleware", () async {
    var rgx = new RegExp("^Hello, world!");
    var response = await client.get("$url/todos/0");
    print('Response: ${response.body}');

    expect(rgx.firstMatch(response.body).start, equals(0));

    Map todo = JSON.decode(response.body.replaceAll(rgx, ""));
    print("Todo: $todo");
    // expect(todo.keys.length, equals(3));
    expect(todo['text'], equals("Hello"));
    expect(todo['over'], equals("world"));
  });

  test("named actions", () async {
    var response = await client.get("$url/redirect");
    print('Response: ${response.body}');
    expect(response.body, equals("Hello, \"world!\""));
  });
}
