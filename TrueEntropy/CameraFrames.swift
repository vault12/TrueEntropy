// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import Foundation
import AVFoundation

protocol CameraFramesDelegate {
  func uploadEntropy(entropy: [UInt8], blockNumber: Int)
}

// This class captures raw frames of an iOS camera and passes
// them as CMSampleBuffer to the EntropyCollector instance.
//
// This is the highest level container in the extraction hierachy. It manages
// Entropy Collector which receives the raw camera buffer and passes data
// Samples to Extractor, which in turn uses ExtractAlgorithm for
// the specific conversion to uniform bits. The Collector saves these bits until
// the Collector entropy block is full.

class CameraFrames : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

  var previewLayer: AVCaptureVideoPreviewLayer?
  var camFramesDlg: CameraFramesDelegate?
  var session: AVCaptureSession?
  var extractor: Extractor
  var collector: EntropyCollector
  // var buildPi: BuildPi

  var blockNumber: Int
  var defaults = UserDefaults.standard

  init(dlg:CameraFramesDelegate) {
    camFramesDlg = dlg
    blockNumber = 0

    self.extractor = Extractor.shared
    self.extractor.setMaxBits()
    self.extractor.setChiSquareLimit()

    self.collector = EntropyCollector.shared
    self.collector.setBlockSize()
    // self.buildPi = BuildPi(entropySource:self.collector)
    super.init()

    do {
      let session: AVCaptureSession = AVCaptureSession()
      self.session = session

      session.beginConfiguration()

      let device: AVCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)!
      let input: AVCaptureDeviceInput = try AVCaptureDeviceInput(device: device)
      if session.canAddInput(input) { session.addInput(input) }

      let output: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
      output.alwaysDiscardsLateVideoFrames = true
      output.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)
      ]
      let outputQueue: DispatchQueue = DispatchQueue(label: "outputQueue", attributes: [])
      output.setSampleBufferDelegate(self, queue: outputQueue)
      if session.canAddOutput(output) { session.addOutput(output) }

      previewLayer = AVCaptureVideoPreviewLayer(session: session)

      if session.canSetSessionPreset(.hd4K3840x2160) {
        // If HD4K is supported we will assume this is one of the modern phones
        session.sessionPreset = Constants.cameraPreset
      } else {
        // Otherwise we will downgrade to low memory footprint resolution
        session.sessionPreset = .hd1280x720
      }

      session.commitConfiguration()

      if !session.isRunning { session.startRunning() }
    }
    catch {
      NSLog("catch!")
    }
  }

  func stopSession() {
    self.session!.stopRunning()
    self.collector.reset()
    self.extractor.reset()
  }

  func captureOutput(_ captureOutput: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    autoreleasepool {
      let ctr = self.collector
      // Sending raw buffer to be processed by Collector
      ctr.collect(buffer: sampleBuffer)

      func processBlock() {
        if ctr.blockReady() {  // Collector filled out full entropy block
          let entropy = ctr.getEntropy()    // Lets get it
          if entropy.count == 0 { return }  // Error guard
          blockNumber += 1
          camFramesDlg?.uploadEntropy(entropy: entropy, blockNumber: blockNumber)
          if  !defaults.bool(forKey: "block_amount_unlimited") &&
              blockNumber == defaults.integer(forKey: "block_amount")
          { self.stopSession() } else { processBlock() }
          // If blocks are small, Collector buffer might be bigger then one
          // block. Call processBlock() recursively while blockReady() is true
        }
      }

      processBlock()
    }
  }
}
