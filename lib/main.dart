// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ObjectDetectionPage(),
    );
  }
}

class ObjectDetectionPage extends StatefulWidget {
  const ObjectDetectionPage({super.key});

  @override
  State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
}

class DetectionResult {
  final List<DetectedObject> objects;
  final List<ImageLabel> imageLabels;
  final Size imageSize;

  DetectionResult({
    required this.objects,
    required this.imageLabels,
    required this.imageSize,
  });
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  DetectionResult? _detectionResult;
  bool _isProcessing = false;
  int? _selectedObjectIndex; // Track which object is selected
  final ScrollController _scrollController = ScrollController();

  // Detection settings - adjustable for better results
  double _labelConfidenceThreshold = 0.4; // Lowered from 0.5
  double _imageQuality = 100; // Max quality for camera

  Future<void> _takePicture() async {
    try {
      // Capture image from camera with high quality settings
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: _imageQuality.toInt(),
        maxWidth: 1920, // Limit to reasonable size for processing
        maxHeight: 1920,
      );

      if (photo == null) return;

      setState(() {
        _image = File(photo.path);
        _isProcessing = true;
        _detectionResult = null;
        _selectedObjectIndex = null; // Reset selection
      });

      // Process image with both object detection and image labeling
      await _detectObjects(photo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _detectObjects(String imagePath) async {
    ObjectDetector? objectDetector;
    ImageLabeler? imageLabeler;

    try {
      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Get image size
      final File imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );

      // Configure Object Detector with optimized settings
      final objectOptions = ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      );
      objectDetector = ObjectDetector(options: objectOptions);
      final List<DetectedObject> objects = await objectDetector.processImage(
        inputImage,
      );

      print('DEBUG: Object Detection - Found ${objects.length} objects');
      for (var obj in objects) {
        print(
          'DEBUG: Object - Labels: ${obj.labels.map((l) => '${l.text} '
              '(${(l.confidence * 100).toStringAsFixed(1)}%)').join(', ')}',
        );
        print('DEBUG: Object - Bounding box: ${obj.boundingBox}');
        print('DEBUG: Object - Tracking ID: ${obj.trackingId}');
      }

      // Configure Image Labeler with adjustable confidence threshold
      final labelOptions = ImageLabelerOptions(
        confidenceThreshold: _labelConfidenceThreshold,
      );
      imageLabeler = ImageLabeler(options: labelOptions);
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      print('DEBUG: Image Labeling - Found ${labels.length} labels');
      print(
        'DEBUG: Confidence threshold: ${(_labelConfidenceThreshold * 100).toStringAsFixed(0)}%',
      );
      for (var label in labels) {
        print(
          'DEBUG: Label: ${label.label} (${(label.confidence * 100).toStringAsFixed(1)}%)',
        );
      }

      if (mounted) {
        setState(() {
          _detectionResult = DetectionResult(
            objects: objects,
            imageLabels: labels,
            imageSize: imageSize,
          );
        });
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error in _detectObjects: $e');
      print('DEBUG: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error detecting objects: $e')));
      }
    } finally {
      // Clean up
      objectDetector?.close();
      imageLabeler?.close();
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            'Detection Settings',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Label Confidence Threshold
                      Text(
                        'Label Confidence Threshold: ${(_labelConfidenceThreshold * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lower = More labels detected (may include uncertain results)',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Slider(
                        value: _labelConfidenceThreshold,
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        label: '${(_labelConfidenceThreshold * 100).toInt()}%',
                        onChanged: (value) {
                          setModalState(() {
                            _labelConfidenceThreshold = value;
                          });
                          setState(() {
                            _labelConfidenceThreshold = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Image Quality
                      Text(
                        'Image Quality: ${_imageQuality.toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Higher = Better accuracy but slower processing',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Slider(
                        value: _imageQuality,
                        min: 50,
                        max: 100,
                        divisions: 5,
                        label: '${_imageQuality.toInt()}%',
                        onChanged: (value) {
                          setModalState(() {
                            _imageQuality = value;
                          });
                          setState(() {
                            _imageQuality = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Tips
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 20,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tips for Better Detection:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Use good lighting\n'
                              '• Keep camera steady\n'
                              '• Capture objects from different angles\n'
                              '• Ensure objects are clearly visible\n'
                              '• Avoid blurry or dark images',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Detection Settings',
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Center(
        child: _image == null ? _buildInitialView() : _buildResultView(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _takePicture,
        tooltip: 'Take Picture',
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildInitialView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_outlined, size: 100, color: Colors.grey[400]),
        const SizedBox(height: 24),
        Text(
          'Tap the camera button to take a picture',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _showSettings,
          icon: const Icon(Icons.tune),
          label: const Text('Adjust Detection Settings'),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        // Fixed image at top
        Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageWithOverlay(),
          ),
        ),

        // Scrollable content below
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Detection settings info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence threshold: ${(_labelConfidenceThreshold * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _showSettings,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text(
                            'Adjust',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display image-wide labels (most specific)
                  if (_detectionResult?.imageLabels != null &&
                      _detectionResult!.imageLabels.isNotEmpty) ...[
                    Text(
                      'What\'s in this image:',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildImageLabelsCard(_detectionResult!.imageLabels),
                    const SizedBox(height: 24),
                  ],

                  // Display detected objects
                  Text(
                    'Detected Objects (${_detectionResult?.objects.length ?? 0})',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isProcessing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_detectionResult?.objects == null ||
                      _detectionResult!.objects.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'No distinct objects detected',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _showSettings,
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text(
                                'Try lowering confidence threshold',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._detectionResult!.objects.asMap().entries.map((entry) {
                      return _buildObjectCard(entry.value, entry.key + 1);
                    }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWithOverlay() {
    if (_detectionResult == null) {
      return Image.file(_image!, fit: BoxFit.contain);
    }

    return AspectRatio(
      aspectRatio:
          _detectionResult!.imageSize.width /
          _detectionResult!.imageSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The image
          Image.file(_image!, fit: BoxFit.contain),
          // Overlay with bounding boxes
          if (_detectionResult!.objects.isNotEmpty)
            CustomPaint(
              painter: BoundingBoxPainter(
                objects: _detectionResult!.objects,
                imageSize: _detectionResult!.imageSize,
                selectedIndex: _selectedObjectIndex,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageLabelsCard(List<ImageLabel> labels) {
    // Sort by confidence
    final sortedLabels = labels.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sortedLabels.first.label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(sortedLabels.first.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (sortedLabels.length > 1) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Also detected (${sortedLabels.length - 1} more):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedLabels.skip(1).take(10).map((label) {
                  return Chip(
                    label: Text(
                      '${label.label} (${(label.confidence * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 13),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildObjectCard(DetectedObject obj, int index) {
    final labels = obj.labels;
    final boundingBox = obj.boundingBox;
    final isSelected = _selectedObjectIndex == index - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.blue[50] : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedObjectIndex = _selectedObjectIndex == index - 1
                ? null
                : index - 1;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with object number
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getObjectColor(index - 1),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.blue, width: 3)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '#$index',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels.isNotEmpty
                              ? labels.first.text
                              : 'Unknown Object',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (labels.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${(labels.first.confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (labels.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(labels.first.confidence),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getConfidenceLabel(labels.first.confidence),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              // Selection hint
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Highlighted on image above',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Bounding box information
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.crop_free,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Location in image:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Position: (${boundingBox.left.toInt()}, ${boundingBox.top.toInt()})',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'Size: ${boundingBox.width.toInt()} × ${boundingBox.height.toInt()} px',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (obj.trackingId != null)
                      Text(
                        'Tracking ID: ${obj.trackingId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),

              // Additional labels
              if (labels.length > 1) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Other possibilities:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labels.skip(1).map((label) {
                    return Chip(
                      label: Text(
                        '${label.text} (${(label.confidence * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getObjectColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) {
      return Colors.green;
    } else if (confidence >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 0.7) {
      return 'HIGH';
    } else if (confidence >= 0.4) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }
}

// CustomPainter to draw bounding boxes on the image
class BoundingBoxPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final int? selectedIndex;

  BoundingBoxPainter({
    required this.objects,
    required this.imageSize,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factors to map from image coordinates to display coordinates
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Use different colors for each object
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final boundingBox = obj.boundingBox;
      final color = colors[i % colors.length];
      final isSelected = selectedIndex == i;

      // Scale the bounding box coordinates
      final rect = Rect.fromLTWH(
        boundingBox.left * scaleX,
        boundingBox.top * scaleY,
        boundingBox.width * scaleX,
        boundingBox.height * scaleY,
      );

      // Draw the bounding box rectangle
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 6.0 : 3.0;

      canvas.drawRect(rect, paint);

      // Draw highlight effect for selected object
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = color.withAlpha(50)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, highlightPaint);
      }

      // Draw semi-transparent background for label
      final label = obj.labels.isNotEmpty
          ? '#${i + 1}: ${obj.labels.first.text}'
          : '#${i + 1}';

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isSelected ? 16.0 : 14.0,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Draw background for text
      final backgroundRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 8,
        textPainter.width + 16,
        textPainter.height + 8,
      );

      final backgroundPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRect(backgroundRect, backgroundPaint);

      // Draw the text
      textPainter.paint(
        canvas,
        Offset(rect.left + 8, rect.top - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
