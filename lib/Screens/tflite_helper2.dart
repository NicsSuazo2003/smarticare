import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class CataractModel {
  static late Interpreter _interpreter;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      _interpreter =
          await Interpreter.fromAsset('assets/model/cataract_model2.tflite');
      _initialized = true;
    }
  }

  static Future<Map<String, dynamic>> predict(File imageFile) async {
    await init();

    final bytes = await imageFile.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) throw Exception('Cannot decode image');

   
    int size =
        oriImage.width < oriImage.height ? oriImage.width : oriImage.height;
    img.Image squareImage = img.copyCrop(
      oriImage,
      x: (oriImage.width - size) ~/ 2,
      y: (oriImage.height - size) ~/ 2,
      width: size,
      height: size,
    );

    // Resize to 224x224
    img.Image resized = img.copyResize(squareImage, width: 224, height: 224);

    // Input [1, 224, 224, 3], normalized 0–1
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
        }),
      ),
    );

    // Output [1, 3]
    var output = List.generate(1, (_) => List.filled(3, 0.0));

    _interpreter.run(input, output);

    final probs = output[0]; // [p0, p1, p2]

    // Map to your class labels IN THE SAME ORDER as training
    final classNames = ['Normal', 'Immature', 'Mature'];

    // Argmax
    int predictedIndex = 0;
    double maxProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        predictedIndex = i;
      }
    }

    final String predictedClass = classNames[predictedIndex];
    final double confidence = maxProb;

    return {
      'predictedClass': predictedClass,
      'confidence': confidence,
    };
  }
}
