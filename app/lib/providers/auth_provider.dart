import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => throw UnimplementedError('Must be overridden in main'));
final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.read(storageServiceProvider);
  final api = ApiService();
  final key = storage.apiKey;
  if (key != null) api.setApiKey(key);
  return api;
});
final isAuthenticatedProvider = Provider<bool>((ref) => ref.read(storageServiceProvider).hasApiKey);
