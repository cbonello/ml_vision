# ML Vision - Object Detection App

A Flutter application that uses Google ML Kit to detect and classify objects in photos captured with the device camera. Built for iOS 15.5+ and Android, this app demonstrates powerful on-device machine learning capabilities.

## Features

- **Camera Integration**: Tap the camera button to capture photos using the device camera
- **Real-time Object Detection**: Leverages Google ML Kit for accurate object detection and classification
- **Visual Bounding Boxes**: Displays color-coded boxes around detected objects in the image
- **Interactive Selection**: Tap any detected object card to highlight its corresponding bounding box
- **Detailed Results**: Displays detected objects with:
  - Primary object label with highest confidence
  - Multiple classification possibilities per object
  - Confidence scores (percentage)
  - Visual confidence indicators (HIGH/MEDIUM/LOW)
  - Color-coded badges
  - Bounding box coordinates
- **Adjustable Settings**: Configure detection parameters:
  - Confidence threshold slider (adjust sensitivity)
  - Image quality control
- **Split-Screen Layout**: Fixed image display at top with scrollable object list below
- **Clean UI**: Modern Material Design 3 interface
- **On-device Processing**: All detection happens locally using Google's ML Kit
- **Multi-label Classification**: Shows alternative classifications for each detected object

## Requirements

- **iOS**: 15.5 or later (compatible with iOS 26)
- **Android**: API Level 21 or later
- **Xcode**: 13.0 or later (for iOS development)
- **Flutter**: 3.9.2 or later
- **CocoaPods**: Latest version (for iOS)

## Technologies Used

- **Flutter**: Cross-platform framework
- **Google ML Kit**: On-device machine learning for object detection and image labeling
- **Packages**:
  - [`google_mlkit_object_detection`](https://pub.dev/packages/google_mlkit_object_detection) ^0.15.0 - Google ML Kit object detection
  - [`google_mlkit_image_labeling`](https://pub.dev/packages/google_mlkit_image_labeling) ^0.14.1 - Google ML Kit image labeling
  - [`image_picker`](https://pub.dev/packages/image_picker) ^1.1.2 - Camera and photo library access

## Getting Started

### 1. Clone and Setup

```bash
cd ml_vision
flutter pub get
```

### 2. Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

### 3. Run the App

Connect your iOS device or start the iOS simulator:

```bash
flutter run
```

Or open in Xcode:

```bash
open ios/Runner.xcworkspace
```

## iOS Configuration

The project includes all necessary iOS configurations:

### Deployment Target
- Set to iOS 15.5 in both `Podfile` and Xcode project settings

### Permissions
The following permissions are configured in `Info.plist`:

- `NSCameraUsageDescription`: Camera access for taking photos
- `NSPhotoLibraryUsageDescription`: Photo library access for image selection

### Bundle Identifier
- `com.example.mlVision`

## How to Use

1. **Launch the app** on your iOS device
2. **Tap the camera button** (floating action button) to open the camera
3. **Take a picture** of objects you want to detect
4. **View results** showing:
   - Captured image
   - List of detected objects
   - Confidence scores for each detection

## Project Structure

```
lib/
└── main.dart              # Main app with object detection logic

ios/
├── Podfile                # CocoaPods dependencies (iOS 15.5)
├── Runner.xcodeproj/      # Xcode project
└── Runner/
    └── Info.plist         # iOS permissions and configuration
```

## Troubleshooting

### ML Kit dependencies not found

Run:
```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### Building for iOS-13.0 error

Ensure the deployment target is set to iOS 15.5:
- Check `ios/Podfile`: `platform :ios, '15.5'`
- Check Xcode project settings: Target → Deployment Info → iOS 15.5

### No objects detected

ML Kit works best with:
- Clear, well-lit images
- Distinct objects with defined shapes
- Common everyday objects (furniture, food, animals, vehicles, etc.)
- Objects that aren't too small in the frame

### Camera not working

Verify camera permissions are granted in device Settings → Your App → Camera

## Known Limitations

- Requires physical device with camera for best results
- Object detection accuracy depends on Google ML Kit models
- Detection works best with common objects in well-lit conditions
- May not detect very small objects or unusual items

## License

This project is a demonstration application for educational purposes.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Uses [Google ML Kit](https://developers.google.com/ml-kit)
- Object detection via [google_mlkit_object_detection](https://pub.dev/packages/google_mlkit_object_detection) package
