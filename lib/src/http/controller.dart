library angel_framework.http.controller;

import 'dart:async';
import 'dart:mirrors';
import 'package:angel_route/angel_route.dart';
import 'metadata.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'server.dart' show Angel, preInject;

/// Contains a list of the data required for a DI-enabled method to run.
///
/// This improves performance by removing the necessity to reflect a method
/// every time it is requested.
///
/// Regular request handlers can also skip DI entirely, lowering response time
/// and memory use.
class InjectionRequest {
  /// Optional, typed data that can be passed to a DI-enabled method.
  Map<String, Type> named = {};

  /// A list of the arguments required for a DI-enabled method to run.
  final List required = [];

  /// A list of the arguments that can be null in a DI-enabled method.
  final List<String> optional = [];
}

/// Supports grouping routes with shared functionality.
class Controller {
  Angel _app;

  /// The [Angel] application powering this controller.
  Angel get app => _app;

  final bool debug;

  /// If `true` (default), this class will inject itself as a singleton into the [app]'s container when bootstrapped.
  final bool injectSingleton;

  /// Middleware to run before all handlers in this class.
  List middleware = [];

  /// A mapping of route paths to routes, produced from the [Expose] annotations on this class.
  Map<String, Route> routeMappings = {};

  Controller({this.debug: false, this.injectSingleton: true});

  Future call(Angel app) async {
    _app = app;

    if (injectSingleton != false) _app.container.singleton(this);

    // Load global expose decl
    ClassMirror classMirror = reflectClass(this.runtimeType);
    Expose exposeDecl = findExpose();

    if (exposeDecl == null) {
      throw new Exception(
          "All controllers must carry an @Expose() declaration.");
    }

    var routable = new Routable(debug: debug);
    app.use(exposeDecl.path, routable);
    TypeMirror typeMirror = reflectType(this.runtimeType);
    String name = exposeDecl.as?.isNotEmpty == true
        ? exposeDecl.as
        : MirrorSystem.getName(typeMirror.simpleName);

    app.controllers[name] = this;

    // Pre-reflect methods
    InstanceMirror instanceMirror = reflect(this);
    final handlers = []..addAll(exposeDecl.middleware)..addAll(middleware);
    final routeBuilder = _routeBuilder(instanceMirror, routable, handlers);
    classMirror.instanceMembers.forEach(routeBuilder);
    configureRoutes(routable);
  }

  Function _routeBuilder(
      InstanceMirror instanceMirror, Routable routable, List handlers) {
    return (Symbol methodName, MethodMirror method) {
      if (method.isRegularMethod &&
          methodName != #toString &&
          methodName != #noSuchMethod &&
          methodName != #call &&
          methodName != #equals &&
          methodName != #==) {
        Expose exposeDecl = method.metadata
            .map((m) => m.reflectee)
            .firstWhere((r) => r is Expose, orElse: () => null);

        if (exposeDecl == null) return;

        var reflectedMethod = instanceMirror.getField(methodName).reflectee;
        var middleware = []..addAll(handlers)..addAll(exposeDecl.middleware);
        String name = exposeDecl.as?.isNotEmpty == true
            ? exposeDecl.as
            : MirrorSystem.getName(methodName);

        // Check if normal
        if (method.parameters.length == 2 &&
            method.parameters[0].type.reflectedType == RequestContext &&
            method.parameters[1].type.reflectedType == ResponseContext) {
          // Create a regular route
          routeMappings[name] = routable
              .addRoute(exposeDecl.method, exposeDecl.path, (req, res) async {
            var result = await reflectedMethod(req, res);
            return result is RequestHandler ? await result(req, res) : result;
          }, middleware: middleware);
          return;
        }

        var injection = preInject(reflectedMethod);

        if (exposeDecl?.allowNull?.isNotEmpty == true)
          injection.optional?.addAll(exposeDecl.allowNull);

        routeMappings[name] = routable.addRoute(exposeDecl.method,
            exposeDecl.path, handleContained(reflectedMethod, injection),
            middleware: middleware);
      }
    };
  }

  /// Used to add additional routes to the router from within a [Controller].
  void configureRoutes(Routable routable) {}

  /// Finds the [Expose] declaration for this class.
  Expose findExpose() => reflectClass(runtimeType)
      .metadata
      .map((m) => m.reflectee)
      .firstWhere((r) => r is Expose, orElse: () => null);
}

/// Shortcut for calling [preInject], and then [handleContained].
///
/// Use this to instantly create a request handler for a DI-enabled method.
RequestHandler createDynamicHandler(handler,
    {Iterable<String> optional: const []}) {
  var injection = preInject(handler);
  injection.optional.addAll(optional ?? []);
  return handleContained(handler, injection);
}
/// Handles a request with a DI-enabled handler.
RequestHandler handleContained(handler, InjectionRequest injection) {
  return (RequestContext req, ResponseContext res) async {
    List args = [];

    void inject(requirement) {
      var propFromApp;

      if (requirement == RequestContext) {
        args.add(req);
      } else if (requirement == ResponseContext) {
        args.add(res);
      } else if (requirement is String) {
        if (req.params.containsKey(requirement)) {
          args.add(req.params[requirement]);
        } else if (req.injections.containsKey(requirement))
          args.add(req.injections[requirement]);
        else if (req.properties.containsKey(requirement))
          args.add(req.properties[requirement]);
        else if ((propFromApp = req.app.findProperty(requirement)) != null)
          args.add(propFromApp);
        else if (injection.optional.contains(requirement))
          args.add(null);
        else {
          throw new ArgumentError(
              "Cannot resolve parameter '$requirement' within handler.");
        }
      } else if (requirement is List &&
          requirement.length == 2 &&
          requirement.first is String &&
          requirement.last is Type) {
        String key = requirement.first;
        Type type = requirement.last;

        if (req.params.containsKey(key) ||
            req.injections.containsKey(key) ||
            req.properties.containsKey(key) ||
            req.app.properties.containsKey(key)) {
          inject(key);
        } else
          inject(type);
      } else if (requirement is Type && requirement != dynamic) {
        if (req.injections.containsKey(requirement))
          args.add(req.injections[requirement]);
        else
          args.add(req.app.container.make(requirement));
      } else {
        throw new ArgumentError(
            '$requirement cannot be injected into a request handler.');
      }
    }

    Map<Symbol, dynamic> named = {};
    injection.required.forEach(inject);

    injection.named.forEach((k, v) {
      var name = new Symbol(k);
      if (req.params.containsKey(k))
        named[name] = v;
      else if (req.injections.containsKey(k))
        named[name] = v;
      else if (req.injections.containsKey(v) && v != dynamic)
        named[name] = v;
      else {
        try {
          named[name] = req.app.container.make(v);
        } catch (e) {
          named[name] = null;
        }
      }
    });

    var result = Function.apply(handler, args, named);
    return result is Future ? await result : result;
  };
}
