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

    // Preprocess the image (resize, normalize, etc.)
    final bytes = await imageFile.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) throw Exception('Cannot decode image');
    img.Image resized = img.copyResize(oriImage, width: 224, height: 224);

    // Build a 4D input tensor [1, 224, 224, 3]
    final input = List.generate(
        1,
        (_) => // batch size 1
            List.generate(
                224,
                (y) => List.generate(224, (x) {
                      final pixel = resized.getPixel(
                          x, y); // Pixel object in new image package
                      final r = pixel.r / 255.0;
                      final g = pixel.g / 255.0;
                      final b = pixel.b / 255.0;
                      return [r, g, b];
                    })));

    // Output: shape [1, 1] for sigmoid binary classifier
    var output = List.generate(1, (_) => [0.0]);

    _interpreter.run(input, output);

    double probability = output[0][0];

    // Match your Python logic:
    // class_names = ['Cataract', 'Normal']
    // predicted_class = class_names[int(prediction[0] > 0.5)]
    // confidence = prediction[0] if prediction[0] > 0.5 else 1 - prediction[0]
    final classNames = ['Cataract', 'Normal'];
    int predictedIndex = probability > 0.5 ? 1 : 0;
    String predictedClass = classNames[predictedIndex];
    double confidence = predictedIndex == 1 ? probability : 1 - probability;

    return {
      'predictedClass': predictedClass, // String: 'Cataract' or 'Normal'
      'confidence': confidence, // double
    };
  }
}
