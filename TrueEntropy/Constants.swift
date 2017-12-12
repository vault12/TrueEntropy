// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import UIKit
import AVFoundation

struct Constants {
  // Block preferences
  // =========================
  static let blockSizes      = [100, 250, 512, 1024, 1536, 2048]
  static let blockSizeLabels = ["100 KB", "250 KB", "512 KB", "1 MB", "1.5 MB", "2 MB"]

  // Camera
  // =========================
  // Capture setting preset
  // Change to `AVCaptureSession.Preset.medium` or `AVCaptureSession.Preset.low` for faster entropy generation.
  // See all available values on:
  // https://developer.apple.com/documentation/avfoundation/avcapturesession.preset#topics
  static let cameraPreset = AVCaptureSession.Preset.hd1920x1080

  // Extractor/collector preferences
  // =========================
  static let extractorCapacity = 4*1024*1024
  static let skipFrames        = 10
  static let meanRange         = -0.1..<0.1
  static let sampleDelta       = 8

  // Network preferences
  // =========================
  static let waitForResponse = 5
  static let sessionRefresh  = 300.0

  // View preferences
  // =========================
  static let spinnerAnimationDuration = 80.0

  // Colors
  // =========================
  static let mainColor =    UIColor(red:0.32, green:0.81, blue:0.98, alpha:1.00) // Light blue
  static let warningColor = UIColor(red:0.93, green:0.39, blue:0.43, alpha:1.00) // Light red
}
