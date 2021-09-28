import 'dart:io';

import 'package:bitapp_http_x/bitapp_http_x.dart';
import 'package:bitapp_isolates/bitapp_isolates.dart';
import 'package:test/test.dart';
import 'package:bitapp_functional_dart/bitapp_functional_dart.dart';

void main() {
  

    test('Test Request X', () async {
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

    test('Test Connectivity: disable internet connection', () async {
      await RequestX('crossbrowsertesting.com')
              .path('api/v3/livetests/browsers') 
              .params({'format': 'json'})
              .doIsolateRequest()
              .fold(
                (failures) => expect(failures.first.isExceptionOfType(SocketException), true), 
                (val) => fail('Socket Exception Expected'));
    
    });
}
