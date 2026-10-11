import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class CataractModel {
  static late Interpreter _interpreter;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      _interpreter =
          await Interpreter.fromAsset('assets/model/cataract_model.tflite');
      _initialized = true;
    }
  }

  static Future<Map<String, dynamic>> predict(File imageFile) async {
    await init();

    final bytes = await imageFile.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) throw Exception('Cannot decode image');

    // Ensure square aspect ratio before resizing
    int size =
        oriImage.width < oriImage.height ? oriImage.width : oriImage.height;
    img.Image squareImage = img.copyCrop(
      oriImage,
      x: (oriImage.width - size) ~/ 2,
      y: (oriImage.height - size) ~/ 2,
      width: size,
      height: size,
    );

    // Now resize to 224x224
    img.Image resized = img.copyResize(squareImage, width: 224, height: 224);

    // Build a 4D input tensor [1, 224, 224, 3]
    final input = List.generate(
        1,
        (_) => List.generate(
            224,
            (y) => List.generate(224, (x) {
                  final pixel = resized.getPixel(x, y);
                  final r = pixel.r / 255.0;
                  final g = pixel.g / 255.0;
                  final b = pixel.b / 255.0;
                  return [r, g, b];
                })));

    var output = List.generate(1, (_) => [0.0]);
    _interpreter.run(input, output);

    double probability = output[0][0];
    final classNames = ['Cataract', 'Normal'];
    int predictedIndex = probability > 0.5 ? 1 : 0;
    String predictedClass = classNames[predictedIndex];
    double confidence = predictedIndex == 1 ? probability : 1 - probability;

    return {
      'predictedClass': predictedClass,
      'confidence': confidence,
    };
  }
}
