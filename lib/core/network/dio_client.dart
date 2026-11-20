import 'package:dio/dio.dart';

class DioClient {
  static Dio createDio({String? baseUrl, String? authToken}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Accept': 'application/json',
          if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  }
}
