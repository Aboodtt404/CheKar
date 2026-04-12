import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device car photo validator using MobileNetV3-Small (ImageNet).
///
/// Runs a ~10MB model locally to check if a photo contains a car
/// before uploading to the server. Saves bandwidth and API calls.
class CarValidator {
  static const String _modelPath = 'assets/models/mobilenetv3_small.tflite';
  static const int _inputSize = 224;
  static const double _vehicleThreshold = 0.15;

  /// ImageNet class indices for vehicles + car parts visible in close-ups.
  static const Set<int> _vehicleClasses = {
    // Vehicles
    407, // ambulance
    436, // beach wagon / station wagon
    468, // cab / taxi
    511, // convertible
    555, // fire engine
    565, // freight car
    569, // garbage truck
    609, // jeep
    627, // limousine
    654, // minibus
    656, // minivan
    675, // moving van
    705, // passenger car
    717, // pickup truck
    734, // police van
    751, // race car
    757, // recreational vehicle / RV
    779, // school bus
    817, // sports car
    829, // streetcar
    864, // tow truck
    867, // trailer truck
    874, // trolleybus
    // Car parts (visible in close-up shots)
    475, // car mirror
    479, // car wheel
    581, // grille
    753, // radiator
  };

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(_modelPath);
    _interpreter!.allocateTensors();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Returns true if the image likely contains a car/vehicle.
  Future<bool> isCar(File imageFile) async {
    if (_interpreter == null) await loadModel();
    final bytes = await imageFile.readAsBytes();
    final input = _preprocess(bytes);
    final output = _runInference(input);
    return _isVehicle(output);
  }

  /// Get raw vehicle score for debugging/tuning.
  Future<double> getVehicleScore(File imageFile) async {
    if (_interpreter == null) await loadModel();
    final bytes = await imageFile.readAsBytes();
    final input = _preprocess(bytes);
    final output = _runInference(input);
    double score = 0.0;
    for (final idx in _vehicleClasses) {
      score += output[idx];
    }
    return score;
  }

  /// Preprocess: decode → resize 224x224 → ImageNet normalize → Float32 tensor.
  Float32List _preprocess(Uint8List rawBytes) {
    img.Image? original = img.decodeImage(rawBytes);
    if (original == null) throw Exception('Failed to decode image');

    // Fix EXIF rotation
    original = img.bakeOrientation(original);

    final resized = img.copyResize(
      original,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // ImageNet normalization
    const mean = [0.485, 0.456, 0.406];
    const std = [0.229, 0.224, 0.225];

    final buffer = Float32List(1 * _inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[idx++] = ((pixel.r.toDouble() / 255.0) - mean[0]) / std[0];
        buffer[idx++] = ((pixel.g.toDouble() / 255.0) - mean[1]) / std[1];
        buffer[idx++] = ((pixel.b.toDouble() / 255.0) - mean[2]) / std[2];
      }
    }
    return buffer;
  }

  /// Run model inference, returns 1000-class softmax probabilities.
  List<double> _runInference(Float32List input) {
    final inputTensor = input.reshape([1, _inputSize, _inputSize, 3]);
    final output = List.filled(1000, 0.0).reshape([1, 1000]);

    _interpreter!.run(inputTensor, output);

    return List<double>.from(output[0]);
  }

  /// Sum all vehicle class probabilities and check threshold.
  bool _isVehicle(List<double> probabilities) {
    double vehicleScore = 0.0;
    for (final idx in _vehicleClasses) {
      vehicleScore += probabilities[idx];
    }
    return vehicleScore >= _vehicleThreshold;
  }
}
