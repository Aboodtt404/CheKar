import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

class InspectionState {
  final Inspection? current;
  final bool isUploading;
  final int uploadedCount;
  final String? error;
  const InspectionState({this.current, this.isUploading = false, this.uploadedCount = 0, this.error});
  InspectionState copyWith({Inspection? current, bool? isUploading, int? uploadedCount, String? error}) =>
    InspectionState(current: current ?? this.current, isUploading: isUploading ?? this.isUploading, uploadedCount: uploadedCount ?? this.uploadedCount, error: error);
}

class InspectionNotifier extends StateNotifier<InspectionState> {
  final ApiService _api;
  final StorageService _storage;
  Timer? _pollTimer;
  InspectionNotifier(this._api, this._storage) : super(const InspectionState());

  Future<String> createInspection({required String carModel, required int year, required int mileage}) async {
    final id = await _api.createInspection(carModel: carModel, year: year, mileage: mileage);
    final inspection = await _api.getInspection(id);
    state = state.copyWith(current: inspection, uploadedCount: 0);
    return id;
  }

  Future<void> uploadPhoto(File photo) async {
    if (state.current == null) return;
    state = state.copyWith(isUploading: true);
    try {
      await _api.uploadPhoto(state.current!.id, photo);
      state = state.copyWith(isUploading: false, uploadedCount: state.uploadedCount + 1);
    } catch (e) { state = state.copyWith(isUploading: false, error: e.toString()); }
  }

  Future<void> triggerInspection() async {
    if (state.current == null) return;
    await _api.triggerInspection(state.current!.id);
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (state.current == null) return;
      try {
        final updated = await _api.getInspection(state.current!.id);
        state = state.copyWith(current: updated);
        if (updated.status == InspectionStatus.completed || updated.status == InspectionStatus.failed) {
          _pollTimer?.cancel();
          await _storage.addToHistory(jsonEncode({'id': updated.id, 'car_model': updated.carModel, 'year': updated.year, 'mileage': updated.mileage, 'trust_score': updated.trustScore, 'status': updated.status.name, 'created_at': updated.createdAt}));
        }
      } catch (_) {}
    });
  }

  void stopPolling() => _pollTimer?.cancel();
  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }
}

final inspectionProvider = StateNotifierProvider<InspectionNotifier, InspectionState>((ref) =>
  InspectionNotifier(ref.read(apiServiceProvider), ref.read(storageServiceProvider)));
