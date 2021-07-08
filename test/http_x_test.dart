import 'package:http_x/http_x.dart';
import 'package:isolates/isolates.dart';
import 'package:test/test.dart';
import 'package:gl_functional/gl_functional.dart';

void main() {
  

    test('First Test', () async {
      await RequestX('crossbrowsertesting.com')
              .path('api/v3/livetests/browsers') 
              .params({'format': 'json'})
              .doIsolateRequest()
              .fold((failures) => fail('ValueExpected'), (val) => print(val));
    
    await RequestX('crossbrowsertesting.com')
              .path('api/v3/livetests/browsers') 
              .params({'format': 'json'})
              .doIsolateRequest()
              .bindFuture((json) => decodeJsonInIsolate(json! as String, (e) => None()))
              .fold<void, List>(
                (failures) => null, 
                  (val) => print (val[0]['api_name']));

    await RequestX('crossbrowsertesting.com')
              .path('api/v3/livetests/browsers') 
              .params({'format': 'json'})
              .useCache()
              .doIsolateRequest()
              .bindFuture((json) => decodeJsonInIsolate(json! as String, (e) => None()))
              .fold<void, List>(
                (failures) => null, 
                  (val) => print (val[0]['api_name']));

    await RequestX('crossbrowsertesting.com')
              .path('api/v3/livetests/browsers') 
              .params({'format': 'json'})
              .useCache()
              .doIsolateRequest()
              .bindFuture((json) => decodeJsonInIsolate(json! as String, (e) => None()))
              .fold<void, List>(
                (failures) => null, 
                  (val) => print (val[0]['api_name']));

    await RequestX('dev-api.campusonline.website')
            .path('login')
            .jsonPost()
            .doIsolateRequest()
            .fold((failures) => 
                    failures.first.fold(
                                        (err) => fail('expect exception'), 
                                        (exc) => expect(401, (exc as BadResponseException).statusCode)), 
                (val) => fail('expect exception'));

    await RequestX('dev-api.campusonline.website')
            .path('login')
            // .jsonPost() Se non lo specifichiamo facciamo una get
            .doRequest()
            .fold((failures) => 
                    failures.first.fold(
                                        (err) => fail('expect exception'), 
                                        (exc) => expect(400, (exc as BadResponseException).statusCode)), // Abbiamo fatto una get!
                (val) => fail('expect exception'));

    await RequestX('dev-api.campusonline.website')
            .path('login')
            .jsonPost()
            .doIsolateRequest()
            .fold((failures) => 
                    failures.first.fold(
                                        (err) => fail('expect exception'), 
                                        (exc) => expect(401, (exc as BadResponseException).statusCode)), // Abbiamo fatto una get!
                (val) => fail('expect exception'));

    await RequestX('dev-api.campusonline.website')
            .path('login')
            .jsonPost()
            .doRequest()
            .fold((failures) => 
                    failures.first.fold(
                                        (err) => fail('expect exception'), 
                                        (exc) => expect(401, (exc as BadResponseException).statusCode)), // Abbiamo fatto una get!
                (val) => fail('expect exception'));              
    });

}
