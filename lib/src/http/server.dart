library angel_framework.http.server;

import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:mirrors';
import 'package:angel_route/angel_route.dart';
import 'package:json_god/json_god.dart' as god;
import 'angel_base.dart';
import 'angel_http_exception.dart';
import 'controller.dart';
import 'fatal_error.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'service.dart';
export 'package:container/container.dart';

final RegExp _straySlashes = new RegExp(r'(^/+)|(/+$)');

/// A function that binds an [Angel] server to an Internet address and port.
typedef Future<HttpServer> ServerGenerator(InternetAddress address, int port);

/// Handles an [AngelHttpException].
typedef Future AngelErrorHandler(
    AngelHttpException err, RequestContext req, ResponseContext res);

/// A function that configures an [AngelBase] server in some way.
typedef Future AngelConfigurer(AngelBase app);

/// A powerful real-time/REST/MVC server class.
class Angel extends AngelBase {
  StreamController<HttpRequest> _afterProcessed =
      new StreamController<HttpRequest>.broadcast();
  StreamController<HttpRequest> _beforeProcessed =
      new StreamController<HttpRequest>.broadcast();
  StreamController<AngelFatalError> _fatalErrorStream =
      new StreamController<AngelFatalError>.broadcast();
  StreamController<Controller> _onController =
      new StreamController<Controller>.broadcast();
  final List<Angel> _children = [];
  Angel _parent;
  final Random _rand = new Random.secure();

  ServerGenerator _serverGenerator = HttpServer.bind;

  /// Fired after a request is processed. Always runs.
  Stream<HttpRequest> get afterProcessed => _afterProcessed.stream;

  /// Fired before a request is processed. Always runs.
  Stream<HttpRequest> get beforeProcessed => _beforeProcessed.stream;

  /// All child application mounted on this instance.
  List<Angel> get children => new List<Angel>.unmodifiable(_children);

  /// Fired on fatal errors.
  Stream<AngelFatalError> get fatalErrorStream => _fatalErrorStream.stream;

  /// Indicates whether the application is running in a production environment.
  ///
  /// The criteria for this is the `ANGEL_ENV` environment variable being set to
  /// `'production'`.
  bool get isProduction => Platform.environment['ANGEL_ENV'] == 'production';

  /// Fired whenever a controller is added to this instance.
  ///
  /// **NOTE**: This is a broadcast stream.
  Stream<Controller> get onController => _onController.stream;

  /// Returns the parent instance of this application, if any.
  Angel get parent => _parent;

  /// Always run before responses are sent.
  ///
  /// These will only not run if an [AngelFatalError] occurs.
  final List<RequestHandler> responseFinalizers = [];

  /// Default error handler, show HTML error page
  AngelErrorHandler _errorHandler =
      (AngelHttpException e, req, ResponseContext res) {
    res.headers[HttpHeaders.CONTENT_TYPE] = ContentType.HTML.toString();
    res.statusCode = e.statusCode;
    res.write("<!DOCTYPE html><html><head><title>${e.message}</title>");
    res.write("</head><body><h1>${e.message}</h1><ul>");
    for (String error in e.errors) {
      res.write("<li>$error</li>");
    }
    res.write("</ul></body></html>");
    res.end();
  };

  /// The handler currently configured to run on [AngelHttpException]s.
  AngelErrorHandler get errorHandler => _errorHandler;

  /// [RequestMiddleware] to be run before all requests.
  final List before = [];

  /// [RequestMiddleware] to be run after all requests.
  final List after = [];

  /// The native HttpServer running this instancce.
  HttpServer httpServer;

  /// Handles a server error.
  _onError(e, [StackTrace st]) {
    _fatalErrorStream.add(new AngelFatalError(error: e, stack: st));
  }

  void _printDebug(x) {
    if (debug) print(x);
  }

  String _randomString(int length) {
    var codeUnits = new List.generate(length, (index) {
      return _rand.nextInt(33) + 89;
    });

    return new String.fromCharCodes(codeUnits);
  }

  /// Starts the server.
  ///
  /// Returns false on failure; otherwise, returns the HttpServer.
  Future<HttpServer> startServer([InternetAddress address, int port]) async {
    final host = address ?? InternetAddress.LOOPBACK_IP_V4;
    this.httpServer = await _serverGenerator(host, port ?? 0);
    return httpServer..listen(handleRequest);
  }

  /// Loads some base dependencies into the service container.
  void bootstrapContainer() {
    container.singleton(this, as: AngelBase);
    container.singleton(this, as: Routable);
    container.singleton(this, as: Router);
    container.singleton(this);

    if (runtimeType != Angel) container.singleton(this, as: Angel);
  }

  Future<bool> executeHandler(
      handler, RequestContext req, ResponseContext res) async {
    if (handler is RequestMiddleware) {
      var result = await handler(req, res);

      if (result is bool)
        return result == true;
      else if (result != null) {
        res.json(result);
        return false;
      } else
        return res.isOpen;
    }

    if (handler is RequestHandler) {
      await handler(req, res);
      return res.isOpen;
    }

    if (handler is Future) {
      var result = await handler;
      if (result is bool)
        return result == true;
      else if (result != null) {
        res.json(result);
        return false;
      } else
        return true;
    }

    if (handler is Function) {
      var result = await runContained(handler, req, res);
      if (result is bool)
        return result == true;
      else if (result != null) {
        res.json(result);
        return false;
      } else
        return true;
    }

    if (requestMiddleware.containsKey(handler)) {
      return await executeHandler(requestMiddleware[handler], req, res);
    }

    // res.willCloseItself = true;
    res.write(god.serialize(handler));
    // await res.io.close();
    return false;
  }

  Future handleRequest(HttpRequest request) async {
    _beforeProcessed.add(request);

    final req = await RequestContext.from(request, this);
    final res = new ResponseContext(request.response, this);
    String requestedUrl = request.uri.path.replaceAll(_straySlashes, '');

    if (requestedUrl.isEmpty) requestedUrl = '/';

    final resolved =
        resolveAll(requestedUrl, requestedUrl, method: request.method);

    for (final result in resolved) req.params.addAll(result.allParams);

    if (resolved.isNotEmpty) {
      final route = resolved.first.route;
      req.inject(Match, route.match(requestedUrl));
    }

    final m = new MiddlewarePipeline(resolved);
    req.inject(MiddlewarePipeline, m);

    final pipeline = []..addAll(before)..addAll(m.handlers)..addAll(after);

    _printDebug('Handler sequence on $requestedUrl: $pipeline');

    for (final handler in pipeline) {
      try {
        _printDebug('Executing handler: $handler');
        final result = await executeHandler(handler, req, res);
        _printDebug('Result: $result');

        if (!result) {
          _printDebug('Last executed handler: $handler');
          break;
        } else {
          _printDebug(
              'Handler completed successfully, did not terminate response: $handler');
        }
      } catch (e, st) {
        _printDebug('Caught error in handler $handler: $e');
        _printDebug(st);

        if (e is AngelHttpException) {
          // Special handling for AngelHttpExceptions :)
          try {
            res.statusCode = e.statusCode;
            String accept = request.headers.value(HttpHeaders.ACCEPT);
            if (accept == "*/*" ||
                accept.contains(ContentType.JSON.mimeType) ||
                accept.contains("application/javascript")) {
              res.json(e.toMap());
            } else {
              await _errorHandler(e, req, res);
            }
            // _finalizeResponse(request, res);
          } catch (e, st) {
            _fatalErrorStream.add(
                new AngelFatalError(request: request, error: e, stack: st));
          }
        } else {
          _fatalErrorStream
              .add(new AngelFatalError(request: request, error: e, stack: st));
        }

        break;
      }
    }

    try {
      _afterProcessed.add(request);

      if (!res.willCloseItself) {
        for (var finalizer in responseFinalizers) {
          await finalizer(req, res);
        }

        for (var key in res.headers.keys) {
          request.response.headers.set(key, res.headers[key]);
        }

        request.response.headers.chunkedTransferEncoding = res.chunked ?? true;

        request.response
          ..statusCode = res.statusCode
          ..cookies.addAll(res.cookies)
          ..add(res.buffer.takeBytes());
        await request.response.close();
      }
    } catch (e) {
      failSilently(request, res);
    }
  }

  // Run a function after injecting from service container
  Future runContained(Function handler, RequestContext req, ResponseContext res,
      {Map<String, dynamic> namedParameters}) async {
    ClosureMirror closureMirror = reflect(handler);
    List args = [];

    for (ParameterMirror parameter in closureMirror.function.parameters) {
      if (parameter.type.reflectedType == RequestContext)
        args.add(req);
      else if (parameter.type.reflectedType == ResponseContext)
        args.add(res);
      else {
        // First, search to see if we can map this to a type
        if (req.injections.containsKey(parameter.type.reflectedType)) {
          args.add(req.injections[parameter.type.reflectedType]);
          continue;
        } else {
          String name = MirrorSystem.getName(parameter.simpleName);

          if (req.params.containsKey(name))
            args.add(req.params[name]);
          else if (name == "req")
            args.add(req);
          else if (name == "res")
            args.add(res);
          else if (req.injections.containsKey(name))
            args.add(req.injections[name]);
          else if (parameter.type.reflectedType != dynamic) {
            args.add(container.make(parameter.type.reflectedType,
                injecting: req.injections));
          } else {
            throw new Exception(
                "Cannot resolve parameter '$name' within handler.");
          }
        }
      }
    }

    return await closureMirror.apply(args).reflectee;
  }

  /// Applies an [AngelConfigurer] to this instance.
  Future configure(AngelConfigurer configurer) async {
    await configurer(this);

    if (configurer is Controller)
      _onController.add(controllers[configurer.exposeDecl.path] = configurer);
  }

  /// Fallback when an error is thrown while handling a request.
  void failSilently(HttpRequest request, ResponseContext res) {}

  /// Starts the server.
  void listen({InternetAddress address, int port: 3000}) {
    runZoned(() async {
      await startServer(address, port);
    }, onError: _onError);
  }

  /// Mounts the child on this router.
  ///
  /// If the router is an [Angel] instance, all controllers
  /// will be copied, as well as services and response finalizers.
  ///
  /// [before] and [after] will be preserved.
  /// 
  /// NOTE: The above will not be properly copied if [path] is
  /// a [RegExp].
  @override
  use(Pattern path, Routable routable,
      {bool hooked: true, String namespace: null}) {
    final head = path.toString().replaceAll(_straySlashes, '');

    if (routable is Angel) {
      _children.add(routable.._parent = this);

      if (routable.before.isNotEmpty) {
        all(path, (req, res) {
          return true;
        }, middleware: routable.before);
      }

      if (routable.after.isNotEmpty) {
        all(path, (req, res) {
          return true;
        }, middleware: routable.after);
      }

      if (routable.responseFinalizers.isNotEmpty) {
        responseFinalizers.add((req, res) async {
          if (req.path.replaceAll(_straySlashes, '').startsWith(head)) {
            for (var finalizer in routable.responseFinalizers)
              await finalizer(req, res);
          }

          return true;
        });
      }

      routable.controllers.forEach((k, v) {
        final tail = k.toString().replaceAll(_straySlashes, '');
        controllers['$head/$tail'.replaceAll(_straySlashes, '')] = v;
      });

      routable.services.forEach((k, v) {
        final tail = k.toString().replaceAll(_straySlashes, '');
        services['$head/$tail'.replaceAll(_straySlashes, '')] = v;
      });
    }

    if (routable is Service) {
      routable.app = this;
    }

    return super.use(path, routable, hooked: hooked, namespace: namespace);
  }

  /// Registers a callback to run upon errors.
  onError(AngelErrorHandler handler) {
    _errorHandler = handler;
  }

  Angel({bool debug: false}) : super(debug: debug) {
    bootstrapContainer();
  }

  /// Creates an HTTPS server.
  /// Provide paths to a certificate chain and server key (both .pem).
  /// If no password is provided, a random one will be generated upon running
  /// the server.
  factory Angel.secure(String certificateChainPath, String serverKeyPath,
      {bool debug: false, String password}) {
    final app = new Angel(debug: debug);

    app._serverGenerator = (InternetAddress address, int port) async {
      var certificateChain =
          Platform.script.resolve(certificateChainPath).toFilePath();
      var serverKey = Platform.script.resolve(serverKeyPath).toFilePath();
      var serverContext = new SecurityContext();
      serverContext.useCertificateChain(certificateChain);
      serverContext.usePrivateKey(serverKey,
          password: password ?? app._randomString(8));

      return await HttpServer.bindSecure(address, port, serverContext);
    };

    return app;
  }
}
