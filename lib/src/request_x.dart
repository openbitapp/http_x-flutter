import 'package:bitapp_functional_dart/bitapp_functional_dart.dart';
import 'package:http/http.dart';
import 'package:bitapp_http_x/src/singleton_cache_manager.dart';
import 'package:bitapp_http_x/src/exceptions.dart';
import 'package:bitapp_http_x/src/request_methods.dart';
import 'package:bitapp_isolates/bitapp_isolates.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Isolate entry point per la get
void _getRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
  final uriOrUrl = requestParam.param['uriOrUrl'];
  final uri = _getUri(uriOrUrl);
  final bool getResponseBytes = requestParam.param['getResponseBytes'];

  http.get (uri, headers: requestParam.param['headers'])
      .then((response) {
        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          if(getResponseBytes)
          {
            requestParam.sendPort?.send(response.bodyBytes);
          }
          else {
            // Usiamo la utf8.decode perché in alcuni casi diceva che il body della response era malformed (Che aria è)
            // Forse adesso è risolto ma non si sa mai
            requestParam.sendPort?.send(utf8.decode(response.bodyBytes)); 
          }
        } else {
          throw BadResponseException(response.statusCode, responseMessage: response.body);
        }      
      });
}

/// Isolate entry point per la post
void _postRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
  _uploadContent(requestParam, http.post);
}

/// Isolate entry point per la put
void _putRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
   _uploadContent(requestParam, http.put);
}

/// Isolate entry point per la delete
void _deleteRequest (IsolateParameter<Map<String, dynamic>> requestParam) {  
  _uploadContent(requestParam, http.delete);
}

void _patchRequest (IsolateParameter<Map<String, dynamic>> requestParam) {
  _uploadContent(requestParam, http.patch);
}


typedef _UploadRequest = Future<Response> Function(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding});

void _uploadContent(IsolateParameter<Map<String, dynamic>> requestParam, _UploadRequest request) {  
  final uriOrUrl = requestParam.param['uriOrUrl'];
  final uri = _getUri(uriOrUrl);
  request(uri, headers: requestParam.param['headers'], body: requestParam.param['jsonBody'])
    .then((response) {
        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          requestParam.sendPort?.send(utf8.decode(response.bodyBytes));
        } else {
          throw BadResponseException(response.statusCode, responseMessage: response.body);
        }      
      });
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

class RequestX {  
  bool _decodeResponseBodyBytes = false;
  bool _getResponseBytes = false;
  Duration _cacheDuration = Duration(seconds:30);
  bool _useCache = false;
  bool _isHttps = true;
  RequestMethod _method = RequestMethod.get;
  Duration _timeout = const Duration(seconds:30);
  final String _authority;
  final String _url;
  String _unencodedPath = '';
  
  final Map<String, String> _headers = {};
  final Map<String, String> _params = {};
  final Map<String, dynamic> _jsonBody = {};

  RequestX (this._authority) : _url = ''
  {
    _debugCheckAuthorityFormat(_authority);
  }

  RequestX.fromUrl (this._url) : _authority = '';

  Uri getUri() => _url.isEmpty 
                        ? _isHttps 
                            ? Uri.https(_authority, _unencodedPath, _params)
                            : Uri.http(_authority, _unencodedPath, _params)
                        : Uri.parse (_url);
  
   /// L'`assert` all'interno del metodo viene richiamato solo nel Debug, \
  /// per essere sicuri che l'autority sia corretta ossia non inizi con http e che non contenga /
  static void _debugCheckAuthorityFormat(String authority) {
    assert(!authority.startsWith('http') && !authority.contains('/'),
        'authority NON deve iniziare con http o https e NON deve contenere alcun carattere /. Es.: www.microsoft.com');
  }

  /// È la funzione che lancia l'isolate per cui deve essere statico e non avere riferimenti a altre classi.
  /// Per questo non passiamo un parametro di tipo `RequestX` ma i vari valori
  /// È privata perché si forza l'uso del metodo `isolate()` dell'extension
  static IsolateManager<Map<String, dynamic>> _isolateRequest ({required Uri uri, 
                                                                      RequestMethod requestMethod = RequestMethod.get,
                                                                      bool getResponseBytes = false,
                                                                      Map<String, String> headers = const {}, 
                                                                      Map<String, dynamic> jsonBody = const {}, 
                                                                      Duration timeout = const Duration(seconds:30)})
  {
    var isolateParams = {'uriOrUrl': uri, 'headers': headers};
    if (jsonBody.isNotEmpty)    
    {
      isolateParams['jsonBody'] = json.encode(jsonBody);
    }

    isolateParams['getResponseBytes'] = getResponseBytes;

    var entryPoint = _getRequest;

    switch(requestMethod)
    {
      case RequestMethod.post:
        entryPoint = _postRequest;
      break;

      case RequestMethod.put:
        entryPoint = _putRequest;
      break;

      case RequestMethod.delete:
        entryPoint = _deleteRequest;
      break;

      case RequestMethod.patch:
        entryPoint = _patchRequest;
        break;

      default: // Abbiamo già impostato sopra come default la get
      break;
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

  static void clearCache() => SingletonHttpCacheManager().clearCache();
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

  RequestX decodeResponseBodyBytes () {
    _decodeResponseBodyBytes = true;
    return this;
  }

  RequestX put () {
    _method = RequestMethod.put;
    return this;
  }

  RequestX jsonPut () {
    _method = RequestMethod.put;
    _headers['Accept'] = 'application/json';
    _headers['Content-Type'] = 'application/json; charset=UTF-8';
    return this;
  }

  RequestX jsonPatch () {
    _method = RequestMethod.patch;
    _headers['Accept'] = 'application/json';
    _headers['Content-Type'] = 'application/json; charset=UTF-8';
    return this;
  }

  RequestX delete () {
    _method = RequestMethod.delete;
    return this;
  }

  RequestX jsonDelete () {
    _method = RequestMethod.delete;
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

  RequestX getResponseBytes () {
    _getResponseBytes = true;
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

  void _printLog(bool useCache) {
    final logMap = <String, dynamic>{
      "title": "Request log",
      "url": getUri().toString(),
      "headers": _headers,
      "body": _jsonBody,
      "ask for cached data": useCache
    };

    final logger = Logger();
    logger.i(logMap);
  }

  /// La `doRequest`fa la chiamata senza isolate
  /// Per eseguire la chiamata in un isolate, usare `doIsolateRequest()`._authoritySe è stata impostata la cache tramite `useCache` tenta di recuperare 
  /// il valore dalla cache. Se non esiste, esegue la chiamata e poi salva il valore nella cache usando come id
  /// l'url della chiamata. 
  Future<Validation<T>> doRequest<T> ()
  {
    var uri = getUri();
    var cacheId = uri.toString();
    var request = () => http.get (uri, headers: _headers); 

    // La useCache sarà il valore impostato se è una get, false in tutti gli altri casi
    var useCache = _method == RequestMethod.get
        ? _useCache
        : false;


    switch(_method)
    {
      case RequestMethod.post:
        request = () => http.post(uri, headers: _headers, body: json.encode(_jsonBody));
      break;

      case RequestMethod.put:
        request = () => http.put(uri, headers: _headers, body: json.encode(_jsonBody));
      break;

      case RequestMethod.delete:
        request = () => http.delete(uri, headers: _headers, body: json.encode(_jsonBody));
      break;

      case RequestMethod.patch:
        request = () => http.patch(uri, headers: _headers, body: json.encode(_jsonBody));
        break;

      default: // Abbiamo già impostato sopra come default la get
      break;
    }    
    
    var preparedRequest = () => request()
                                  .timeout(_timeout)                      
                                  .then((response) {
                                    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
                                      if(_getResponseBytes)
                                      {
                                        return Valid(response.bodyBytes as T);
                                      }
                                      // Usiamo la utf8.decode perché in alcuni casi diceva che il body della response era malformed (Che aria è)
                                      // Forse adesso è risolto ma non si sa mai. 
                                      // Se senza il decode dà un malformed, chiamare il metodo decodeResponseBodyBytes sulla RequestX
                                      else if(_decodeResponseBodyBytes)
                                      {
                                        return Valid(utf8.decode(response.bodyBytes, allowMalformed: true) as T);
                                      }
                                      else
                                      {
                                        return Valid(response.body as T);
                                      }                                      
                                    } else {
                                      return BadResponseException(response.statusCode, responseMessage: response.body).toInvalid<T>();
                                    }      
                                  })
                                  .catchError((e) {
                                      if (e is Exception)
                                      {
                                        return e.toInvalid<T>();
                                      } 
                                      else if (e is Error)
                                      {
                                        return e.toInvalid<T>();
                                      }
                                  });

    _printLog(useCache);

    if (!useCache)
    {
      return preparedRequest();
    }

    return SingletonHttpCacheManager().getCacheOrDoRequest<T>(preparedRequest, cacheId, _cacheDuration);
  }

  /// Esegue la richiesta in un isolate. Se è stata impostata la cache tramite `useCache` tenta di recuperare 
  /// il valore dalla cache. Se non esiste, esegue la chiamata e poi salva il valore nella cache usando come id
  /// l'url della chiamata. 
  Future<Validation> doIsolateRequest ()
  {
    var uri = getUri();
    var cacheId = uri.toString();
    var request = () => RequestX._isolateRequest(uri: uri, getResponseBytes: _getResponseBytes,  requestMethod: _method, headers: _headers, timeout: _timeout, jsonBody: _jsonBody).start();

    // La useCache sarà il valore impostato se è una get, false in tutti gli altri casi
    var useCache = _method == RequestMethod.get
                      ? _useCache
                      : false;

    _printLog(useCache);

    if (!useCache)
    {
      return request();
    }
    
    return SingletonHttpCacheManager().getCacheOrDoRequest(request, cacheId, _cacheDuration);
  }
}