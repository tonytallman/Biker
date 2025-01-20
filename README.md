# Biker

Biker is a simple iOS bike-computer app designed as a demonstration of software-design principles. This project is focused on clean, maintainable, and scalable code architecture. The UI is not the point of the app and will not be polished at first.

# Objectives

The primary goals of this project are to:
1.	Demonstrate dependency injection.
2.	Demonstrate development of independent modules (Swift package) that can be developed in parallel.
3.	Demonstrate some SOLID principles.

# Technical Details

-	Language: Swift
-	Platform: iOS
-	Minimum iOS Version: 15.0
-	Key Frameworks: UIKit/SwiftUI, CoreMotion, CoreLocation

# Installation

	1.	Clone the repository:

git clone https://github.com/tonytallman/Biker.git
cd biker

	2.	Open the project in Xcode:

open Biker.xcodeproj

	3.	Build and run the app on your iOS device or simulator.

# Code Structure

The app utilizes local Swift packages to isolate functionality.
- Biker project with iOS target
- BikerCore package with cross-platform business logic
- independent local packages with specific atomic functionality like fake speed provider

# Road Map

## Phase I
- speed metric
- fake speed source
- speed-units preference

## Phase II
- speed source based on on-device location services

## Phase III
- BLE speed source
- prioritized composite speed source, prioritizes BLE source over device location-service source

## Phase IV
- cadence metric
- fake cadence source
- heart-rate metric
- fake heart-rate source

## Phase V
- demo mode
- demo source for all metrics

# Contributions

While this project is primarily for demonstration purposes, contributions are welcome! Feel free to submit issues or pull requests to enhance the app.

# License

This project is licensed under the MIT License. See the LICENSE file for details.
