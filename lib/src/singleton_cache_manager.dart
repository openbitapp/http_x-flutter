import 'package:bitapp_cache/bitapp_cache.dart';
import 'package:bitapp_functional_dart/bitapp_functional_dart.dart';
import 'package:logger/logger.dart';

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
                          (some) {
                            final logger = Logger();
                            logger.i('Cached data returned for $cacheId');
                            return Valid(some).toFuture();
                          });
  }

  void clearCache() => cache.clear();
}