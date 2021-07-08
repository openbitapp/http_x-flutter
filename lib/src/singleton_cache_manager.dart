import 'package:cache/cache.dart';
import 'package:gl_functional/gl_functional.dart';

typedef Request = Future<Validation<String>> Function();

class SingletonHttpCacheManager {
  static final SingletonHttpCacheManager _singleton = SingletonHttpCacheManager._internal();

  factory SingletonHttpCacheManager() {
    return _singleton;
  }

  CacheService _cache = MemoryCache();
  CacheService get cache => _cache;
  SingletonHttpCacheManager._internal();
  
  /// Da chiamare allo startup dell'applicazione per inizializzare il tipo di cache.
  /// Se non viene usata, la cache di default sarà di tipo `MemoryCache`  
  static void Init(CacheService cache) => SingletonHttpCacheManager ()._cache = cache;

  Future<Validation<String>> getCacheOrDoRequest (Request request, String cacheId, Duration cacheDuration)
  {
    return _cache.getBack<String>(cacheId: cacheId)
                    .fold(() =>
                                request()
                                    .fold((failures) => failures.first.toInvalid(), 
                                          (val) {
                                            _cache.add(object: val!, cacheId: cacheId, expireAfter: cacheDuration);
                                            return Valid(val as String);
                                          }), 
                          (some) => Valid(some).toFuture());
  }

  void clearCache() => cache.clear();
}