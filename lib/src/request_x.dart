import 'package:cache/cache.dart';
import 'package:gl_functional/gl_functional.dart';
import 'package:http_x/src/singleton_cache_manager.dart';
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

// typedef Request = Future<Validation<String>> Function();

// CacheService _cache = MemoryCache(); 
// Future<Validation<String>> _getCacheOrDoRequest (Request request, String cacheId, Duration cacheDuration)
// {
//   return _cache.getBack<String>(cacheId: cacheId)
//                   .fold(() =>
//                               request()
//                                   .fold((failures) => failures.first.toInvalid(), 
//                                         (val) {
//                                           _cache.add(object: val!, cacheId: cacheId, expireAfter: cacheDuration);
//                                           return Valid(val as String);
//                                         }), 
//                         (some) => Valid(some).toFuture());
// }

class RequestX<T> {  
  Duration _cacheDuration = Duration(seconds:30);
  bool _useCache = false;
  bool _isHttps = true;
  RequestMethod _method = RequestMethod.get;
  Duration _timeout = const Duration(seconds:30);
  final String _authority;
  String _unencodedPath = '';
  final Map<String, String> _headers = {};
  final Map<String, String> _params = {};
  final Map<String, dynamic> _jsonBody = {};

  RequestX (this._authority) {
    _debugCheckAuthorityFormat(_authority);
  }

  Uri getUri() => _isHttps ? Uri.https(_authority, _unencodedPath, _params)
                          : Uri.http(_authority, _unencodedPath, _params);
  
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
    _isHttps = false;
    return this;
  }

  RequestX post () {
    _method = RequestMethod.post;
    return this;
  }

  RequestX jsonPost () {
    _method = RequestMethod.post;
    _headers['Accept'] = 'application/json';
    _headers['Content-Type'] = 'application/json; charset=UTF-8';
    return this;
  }

  RequestX get () {
    _method = RequestMethod.get;
    return this;
  }

  RequestX jsonGet () {
    _method = RequestMethod.get;
    _headers['Accept'] = 'application/json';
    return this;
  }

  RequestX path (String path) {
    _unencodedPath = path;
    return this;
  }

  RequestX headers (Map<String, String> headers) {
    _headers.addAll(headers);
    return this;
  }

  RequestX params (Map<String, String> params) {
    _params.addAll(params);
    return this;
  }

  RequestX body (Map<String, dynamic> body) {
    _jsonBody.addAll(body);
    return this;
  }

  /// Usare per salvare il rilultato nella cache o riottenerlo alla prossiam chiamata.
  /// L'id della cache è l'url di chiamata
  RequestX useCache ({Duration duration = const Duration(seconds:30)}) {
    _useCache = true;    
    _cacheDuration = duration;
    return this;
  }

  /// La `doRequest`fa la chiamata senza isolate
  /// Per eseguire la chiamata in un isolate, usare `doIsolateRequest()`
  Future<Validation<String>> doRequest ()
  {
    var uri = getUri();
    var cacheId = uri.toString();
    var request = () => http.get (uri, headers: _headers); 
    if (_method == RequestMethod.post) {
      request = () => http.post(uri, headers: _headers, body: json.encode(_jsonBody));
    }
    var preparedRequest = () => request()
                                  .timeout(_timeout)                      
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
    
    if (!_useCache)
    {
      return preparedRequest();
    }

    return SingletonHttpCacheManager().getCacheOrDoRequest(preparedRequest, cacheId, _cacheDuration);
  }

  /// Esegue la richiesta in un isolate.
  Future<Validation<String>> doIsolateRequest ()
  {    
    var uri = getUri();
    var cacheId = uri.toString();
    var request = () => RequestX._isolateRequest(uri: uri, requestMethod: _method, headers: _headers, timeout: _timeout, jsonBody: _jsonBody).start();
    if (!_useCache)
    {
      return request();
    }
    return SingletonHttpCacheManager().getCacheOrDoRequest(request, cacheId, _cacheDuration);
  }
}