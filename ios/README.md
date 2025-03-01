# zkHotdog iOS App 📱

This iOS application uses ARKit and SceneKit to capture precise measurements in 3D space and submit them for verification through zero-knowledge proofs.

## Features

- **AR Measurement**: Place anchor points in 3D space to measure objects
- **Image Capture**: Take photos of measured objects for verification
- **Secure Submission**: Send measurements and images to the backend for ZK proof generation
- **Verification Status**: Check the status of submitted measurements
- **Privacy-Preserving**: Your actual measurement data remains private while still being verifiable

## Setup

1. Install Xcode 14.0 or later
2. Open `zkHotdog.xcodeproj` in Xcode
3. Configure signing and team in project settings
4. Set the backend URL in `MeasurementViewController.swift`
5. Build and run on a device with ARKit support (iPhone or iPad with LiDAR recommended)

## Usage

1. Launch the app and allow camera permissions
2. Point your device at the object you want to measure
3. Tap to place the start point
4. Move to the end position and tap to place the end point
5. The measurement will be displayed on screen
6. Tap "Submit" to generate a zero-knowledge proof of your measurement
7. The app will upload the data and show you the verification status

## Requirements

- iOS 16.0 or later
- iPhone with ARKit support (iPhone 12 or later recommended)
- Camera and location permissions

## Development

- **UI**: Built with UIKit and ARKit
- **Measurement**: Uses SceneKit for 3D point placement and distance calculation
- **Networking**: URLSession for API communication
- **Data Flow**: 
  1. Capture measurement and image
  2. Upload to backend
  3. Receive verification status
  4. View attestation on the blockchain

## Contributing

Feel free to contribute to the iOS app by submitting pull requests or reporting issues.