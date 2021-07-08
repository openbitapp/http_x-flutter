import 'package:gl_functional/gl_functional.dart';
import 'package:http_x/src/exceptions.dart';
import 'package:http_x/src/request_methods.dart';
import 'package:isolates/isolates.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Isolate entry point per la get
String _getRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
  final uriOrUrl = requestParam.param['uriOrUrl'];
  final uri = _getUri(uriOrUrl);

  http.get (uri, headers: requestParam.param['headers'])
      .then((response) {
        if (response.statusCode == 200) {
          requestParam.sendPort?.send(utf8.decode(response.bodyBytes));
        } else {
          throw BadResponseException(response.statusCode, responseMessage: response.body);
        }      
      });

  return '';
}

/// Isolate entry point per la post
String _postRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
  final uriOrUrl = requestParam.param['uriOrUrl'];
  final uri = _getUri(uriOrUrl);

  http.post(uri, headers: requestParam.param['headers'], body: requestParam.param['jsonBody'])
      .then((response) {
        if (response.statusCode == 200) {
          requestParam.sendPort?.send(utf8.decode(response.bodyBytes));
        } else {
          throw BadResponseException(response.statusCode, responseMessage: response.body);
        }      
      });

  return '';
}

Uri _getUri(dynamic uriOrUrl)
{
  Uri uri;
  if (uriOrUrl is String)
  {
    uri = Uri.parse(uriOrUrl);
  }
  else {
    uri = uriOrUrl as Uri;
  }
  
  return uri;
}

/// Isolate entry point per la decode del json 
dynamic _jsonDecode(IsolateParameter<String> responseStringParam)
{
  final jsonRes = json.decode(responseStringParam.param);
  responseStringParam.sendPort?.send(jsonRes);
}

/// Isolate entry point per la encode del json
dynamic _jsonEncode(IsolateParameter<String> jsonToEncode)
{
  final jsonRes = json.encode(jsonToEncode);
  jsonToEncode.sendPort?.send(jsonRes);
}


extension Decoders on String {
  Future<Validation<T>> toJsonIsolate<T> () 
      => IsolateManager.prepare(this, isolateEntryPoint: _jsonDecode, customMessageToError: (e) => None()).start() as Future<Validation<T>>;

  Future<Validation<T>> decodeJsonInIsolate<T> () 
      => IsolateManager.prepare(this, isolateEntryPoint: _jsonEncode, customMessageToError: (e) => None()).start() as Future<Validation<T>>;
}

class RequestX<T> {
  bool isHttps = true;
  RequestMethod requestMethod = RequestMethod.get;
  Duration timeout = const Duration(seconds:30);
  final String authority;
  String unencodedPath = '';
  Map<String, String> requestHeaders = {};
  Map<String, String> requestParams = {};
  Map<String, dynamic> jsonBody = {};

  RequestX (this.authority) {
    _debugCheckAuthorityFormat(authority);
  }

  Uri getUri() => isHttps ? Uri.https(authority, unencodedPath, requestParams)
                          : Uri.http(authority, unencodedPath, requestParams);
  
   /// L'`assert` all'interno del metodo viene richiamato solo nel Debug, \
  /// per essere sicuri che l'autority sia corretta ossia non inizi con http e che non contenga /
  static void _debugCheckAuthorityFormat(String authority) {
    assert(!authority.startsWith('http') && !authority.contains('/'),
        'authority NON deve iniziare con http o https e NON deve contenere alcun carattere /. Es.: www.microsoft.com');
  }

  /// È la funzione che lancia l'isolate per cui deve essere statico e non avere riferimenti a altre classi.
  /// Per questo non passiamo un parametro di tipo `RequestX` ma i vari valori
  /// È privata perché si forza l'uso del metodo `isolate()` dell'extension
  static IsolateManager<Map<String, dynamic>, String> _isolateRequest ({required Uri uri, 
                                                                      RequestMethod requestMethod = RequestMethod.get,
                                                                      Map<String, String> headers = const {}, 
                                                                      Map<String, dynamic> jsonBody = const {}, 
                                                                      Duration timeout = const Duration(seconds:30)})
  {
    var isolateParams = {'uriOrUrl': uri, 'headers': headers};
    if (jsonBody.isNotEmpty)    
    {
      isolateParams['jsonBody'] = json.encode(jsonBody);
    }

    var entryPoint = _getRequest;
    if (requestMethod == RequestMethod.post)
    {
      entryPoint = _postRequest;
    }

    return IsolateManager.prepare(isolateParams, 
                                  isolateEntryPoint: entryPoint, 
                                  timeout: timeout,
                                  customMessageToError: (error) {
                                    if (error.startsWith('Bad response')) {
                                      return Some(BadResponseException.fromString(error).toFail());
                                    }
                                    else {
                                      return None();
                                    }
                                  });
  } 
}

/// Extension che permette di costruire la richiesta con un linguaggio fluent
extension Fluent on RequestX {
  RequestX isHttp () {
    isHttps = false;
    return this;
  }

  RequestX post () {
    requestMethod = RequestMethod.post;
    return this;
  }

  RequestX jsonPost () {
    requestMethod = RequestMethod.post;
    requestHeaders['Accept'] = 'application/json';
    requestHeaders['Content-Type'] = 'application/json; charset=UTF-8';
    return this;
  }

  RequestX get () {
    requestMethod = RequestMethod.get;
    return this;
  }

  RequestX jsonGet () {
    requestMethod = RequestMethod.get;
    requestHeaders['Accept'] = 'application/json';
    return this;
  }

  RequestX path (String path) {
    unencodedPath = path;
    return this;
  }

  RequestX headers (Map<String, String> headers) {
    requestHeaders.addAll(headers);
    return this;
  }

  RequestX params (Map<String, String> params) {
    requestParams.addAll(params);
    return this;
  }

  RequestX body (Map<String, dynamic> body) {
    jsonBody.addAll(body);
    return this;
  }

  /// La `doRequest`fa la chiamata senza isolate
  /// Per eseguire la chiamata in un isolate, usare `isolate()` e successivamente chiamare
  /// la `start()`
  Future<Validation<String>> doRequest () async
  {
    var uri = getUri();
    var request = () => http.get (uri, headers: requestHeaders); 
    if (requestMethod == RequestMethod.post) {
      request = () => http.post(uri, headers: requestHeaders, body: json.encode(jsonBody));
    }
    
    return await request()
                      .timeout(timeout)                      
                      .then((response) {
                        if (response.statusCode == 200) {
                          return Valid(utf8.decode(response.bodyBytes));
                        } else {
                          return BadResponseException(response.statusCode, responseMessage: response.body).toInvalid<String>();
                        }      
                      })
                      .catchError((e) {
                          if (e is Exception)
                          {
                            return e.toInvalid<String>();
                          } 
                          else if (e is Error)
                          {
                            return e.toInvalid<String>();
                          }
                      });
  }

  /// Prepara l'isolate. Chiamare la `start()` dopo questa chiamata
  IsolateManager<Map<String, dynamic>, String> isolate ()
  {
    var uri = getUri();
    return RequestX._isolateRequest(uri: uri, requestMethod: requestMethod, headers: requestHeaders, timeout: timeout, jsonBody: jsonBody);
  }
}