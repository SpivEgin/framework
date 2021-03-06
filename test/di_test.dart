import 'dart:convert';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_route/angel_route.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'common.dart';

final String TEXT = "make your bed";
final String OVER = "never";

main() {
  Angel app;
  http.Client client;
  HttpServer server;
  String url;

  setUp(() async {
    app = new Angel(debug: true);
    client = new http.Client();

    // Inject some todos
    app.container.singleton(new Todo(text: TEXT, over: OVER));

    app.get("/errands", (Todo singleton) => singleton);
    app.get("/errands3",
        ({Errand singleton, Todo foo, RequestContext req}) => singleton.text);
    await app.configure(new SingletonController());
    await app.configure(new ErrandController());

    server = await app.startServer();
    url = "http://${server.address.host}:${server.port}";
  });

  tearDown(() async {
    app = null;
    url = null;
    client.close();
    client = null;
    await server.close(force: true);
  });

  test("singleton in route", () async {
    validateTodoSingleton(await client.get("$url/errands"));
  });

  test("singleton in controller", () async {
    validateTodoSingleton(await client.get("$url/errands2"));
  });

  test("make in route", () async {
    var response = await client.get("$url/errands3");
    String text = await JSON.decode(response.body);
    expect(text, equals(TEXT));
  });

  test("make in controller", () async {
    var response = await client.get("$url/errands4");
    String text = await JSON.decode(response.body);
    expect(text, equals(TEXT));
  });
}

void validateTodoSingleton(response) {
  Map todo = JSON.decode(response.body);
  // expect(todo.keys.length, equals(3));
  expect(todo["id"], equals(null));
  expect(todo["text"], equals(TEXT));
  expect(todo["over"], equals(OVER));
}

@Expose("/errands2")
class SingletonController extends Controller {
  @Expose("/")
  todo(Todo singleton) => singleton;
}

@Expose("/errands4")
class ErrandController extends Controller {
  @Expose("/")
  errand(Errand errand, MiddlewarePipeline pipeline) {
    expect(pipeline, isNotNull);
    return errand.text;
  }
}

class Errand {
  Todo todo;
  String get text => todo.text;

  Errand(this.todo);
}
