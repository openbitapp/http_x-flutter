import 'package:cache/cache.dart';
import 'package:functional_dart/functional_dart.dart';

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

  Future<Validation<T>> getCacheOrDoRequest<T> (Future<Validation<T>> Function() request, String cacheId, Duration cacheDuration)
  {
    return _cache.getBack<T>(cacheId: cacheId)
                    .fold(() =>
                                request()
                                    .fold((failures) => failures.first.toInvalid(), 
                                          (val) {
                                            _cache.add(object: val!, cacheId: cacheId, expireAfter: cacheDuration);
                                            return Valid(val as T);
                                          }), 
                          (some) => Valid(some).toFuture());
  }

  void clearCache() => cache.clear();
}