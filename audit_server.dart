import 'dart:async';
import 'dart:io';

import 'lawdistra.dart';

import 'package:woomera/woomera.dart';
import 'package:mustache4dart/mustache4dart.dart';
import 'package:dartson/dartson.dart';

Future main() async {
  // Creates a new server
  Server server = new Server();
  server.bindAddress = InternetAddress.LOOPBACK_IP_V4;
  server.bindPort = 8080;
  ServerPipeline serverPipeline = server.pipelines.first;
  serverPipeline.get("~/", handleHome);
  serverPipeline.get("~/lawsuit", handleLawsuitRequest);
  serverPipeline.get("~/trace", handleTraceRequest);
  // Runs the server
  print(
      "Servidor iniciado. http://${(server.bindAddress as InternetAddress)
          .host}:${server.bindPort}");
  await server.run();
}

Future<Response> handleHome(Request req) async {
  print("${new DateTime.now()}  ${req.requestPath()}");
  ResponseBuffered response = new ResponseBuffered(ContentType.HTML);
  var pageContent = await new File("web/home.html").readAsString();
  response.write(pageContent);
  return response;
}

Future<Response> handleLawsuitRequest(Request req) async {
  print(
      "${new DateTime.now()}  ${req.requestPath()} ${req.queryParams
          .toString()}");
  ResponseBuffered response = new ResponseBuffered(ContentType.HTML);
  Lawsuit lawsuit;
  if (req.queryParams["cod"] != "") {
    lawsuit = await Lawsuit.relatedLawsuitFactory(req.queryParams["cod"]);
  } else {
    var queryParameters = parseRequestParameters(req.queryParams);
    lawsuit = await Lawsuit.lawsuitFactory(queryParameters);
  }
//  Dartson dson = new Dartson.JSON();
//  print(dson.encode(lawsuit));
  var template = await new File("web/lawsuit.html").readAsString();
  response.write(render(template, lawsuit));
  return response;
}

Map<String, int> parseRequestParameters(RequestParams requestParams) {
  Map<String, int> queryParameters;
  int numero = int.parse(requestParams["num"]);
  int digito = int.parse(requestParams["dig"]);
  int ano = int.parse(requestParams["ano"]);
  int tribunal = int.parse(requestParams["trib"]);
  int vara = int.parse(requestParams["vara"]);
  queryParameters = {
    "numero": numero,
    "digito": digito,
    "ano": ano,
    "tribunal": tribunal,
    "vara": vara
  };
  return queryParameters;
}

Future<Response> handleTraceRequest(Request req) async {
  print(
      "${new DateTime.now()}  ${req.requestPath()} ${req.queryParams
          .toString()}");
  ResponseBuffered response = new ResponseBuffered(ContentType.HTML);
  Trace trace;
  if (req.queryParams["num"] != "") {
    trace = await Trace.traceFactory(
        req.queryParams["num"], req.queryParams["proc"]);
  }
//  Dartson dson = new Dartson.JSON();
//  print(dson.encode(trace));
  var template = await new File("web/trace.html").readAsString();
  response.write(render(template, trace));
  return response;
}
