import 'dart:io';

class BadResponseException implements IOException {
  final String message;
  int statusCode;

  BadResponseException(int statusCode, {String responseMessage = ''}) : message = 'Bad response. Response code: $statusCode\n$responseMessage', statusCode = statusCode;
  BadResponseException.fromString (this.message) : statusCode = -1 {
    final regExp =  RegExp(r'\d+',
                              caseSensitive: false,
                              multiLine: false);
    
    final match = regExp.stringMatch(message);
    if (match != null)
    {     
      statusCode = int.parse(match);
    }
  }

  @override
  String toString() => message;
}