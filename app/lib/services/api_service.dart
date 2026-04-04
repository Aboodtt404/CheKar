import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/inspection.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {'ngrok-skip-browser-warning': 'true'},
    ));
  }

  void setApiKey(String key) { _dio.options.headers['X-API-Key'] = key; }

  Future<bool> validateApiKey(String key) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {'X-API-Key': key, 'ngrok-skip-browser-warning': 'true'},
        followRedirects: true,
      ));
      final response = await dio.get('/health');
      print('validateApiKey response: ${response.statusCode} ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('validateApiKey error: $e');
      return false;
    }
  }

  Future<String> createInspection({required String carModel, required int year, required int mileage, String lang = 'ar', String region = 'cairo'}) async {
    final response = await _dio.post('/inspections', data: {'car_model': carModel, 'year': year, 'mileage': mileage, 'lang': lang, 'region': region});
    return response.data['id'] as String;
  }

  Future<Map<String, dynamic>> uploadPhoto(String inspectionId, File photo) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(photo.path, filename: 'photo.jpg')});
    final response = await _dio.post('/inspections/$inspectionId/photos', data: formData, options: Options(sendTimeout: ApiConfig.uploadTimeout));
    return response.data as Map<String, dynamic>;
  }

  Future<void> triggerInspection(String inspectionId) async { await _dio.post('/inspections/$inspectionId/run'); }

  Future<Inspection> getInspection(String inspectionId) async {
    final response = await _dio.get('/inspections/$inspectionId');
    return Inspection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> downloadReportPdf(String inspectionId, String savePath) async {
    await _dio.download('/inspections/$inspectionId/report.pdf', savePath);
    return savePath;
  }
}
