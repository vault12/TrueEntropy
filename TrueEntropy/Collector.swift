// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

// The Collector processes incoming raw frames CMSampleBuffer and keeps an entropy
// buffer that collects final entropy. When blockReady() is true, we can use
// getEntropy() -> [UInt8] to get block of uniform entropy as bytes from that
// buffer

import Foundation
import AVFoundation

class EntropyCollector {
  static let shared = EntropyCollector(extractor: Extractor.shared,
                                       blockSize: Constants.blockSizes[UserDefaults.standard.integer(forKey: "block_size")] * 1024)
  let extractor:Extractor

  var skipFrames:Int            // How many initial frames to skip
  var meanRange:Range<Double>   // Range of acceptable sample mean
  var sampleDelta:Int           // Delta between samples to be extracted together
  var samples:[Sample]          // Samples collected and unprocessed so far
  var counter:Int               // Received frame counter
  var blockSize:Int             // How many bytes to generate in one block
  var lastChi:Double            // Chi-square of last entropy block
  var totalGenerated:Int        // Counter of all bytes delivered so far
  var rejectedFrames:Int
  var _lastFrame: Frame!

  var corruptPixels: Double { get {
    if samples.count < 3 { return 0 }
    return samples.suffix(3).map { $0.repeat_zeroes }.max()!
  }}

  private init(extractor: Extractor, blockSize:Int = 1024 * 1024) {
    self.extractor    = extractor
    self.blockSize    = blockSize
    self.skipFrames   = Constants.skipFrames
    self.meanRange    = Constants.meanRange
    self.sampleDelta  = Constants.sampleDelta
    self.samples      = [Sample]()
    self.samples.reserveCapacity(sampleDelta * 2)
    self.counter      = 0
    self.lastChi      = 0
    self.totalGenerated = 0
    self.rejectedFrames = 0
  }

  func setBlockSize() {
    self.blockSize = Constants.blockSizes[UserDefaults.standard.integer(forKey: "block_size")] * 1024
  }

  // We collected enough entropy for a full block
  func blockReady() -> Bool { return self.blockSize < self.extractor.pos }


  // Main, outpost entropy collectioon loop. Called on each video frame
  // where frame contents are based for processing as CMSampleBuffer
  func collect(buffer:CMSampleBuffer) {
    autoreleasepool {
      func even(_ n:Int) -> Bool { return n % 2 == 0 }
      let tStart = Date()  // We starting frame processing, start the clock
      defer { self.counter += 1 }  // Increase frame counter at the end
      if self.counter <= self.skipFrames { return }  // Skip camera focusing

      // Current frame
      let f = Frame(pixelBuffer: CMSampleBufferGetImageBuffer(buffer)!)
      if self._lastFrame != nil {  // We recorded lastFrame on previous cycle
        let s = (f - self._lastFrame) // That is our Sample[3] difference
        self._lastFrame = f  // current frame is lastFrame for next cycle
        if s != nil {
          let newSamples = s!

          // Discard samples if there was movement: mean is too far from 0.0
          let newSamplesInRange = newSamples.filter { return self.meanRange.contains($0.mean) }
          self.rejectedFrames += (newSamples.count - newSamplesInRange.count)

          self.samples.append(contentsOf: newSamplesInRange) // Add good samples

          // Extractor algorithm requires minimal number of samples to
          // to work well - accumulate raw samples until we ready to extract
          let ms = self.extractor.algorithm.minimalSamples
          let limit = even(ms) ? ms/2 : 1 + ms/2

          // To deal with time correlations we use samplesDelta distance
          // between samples used togeather.
          if self.samples.count > limit + self.sampleDelta + 1 {
            var extractSamples = [Sample]();
            extractSamples.reserveCapacity(ms + 1)
            for i in 0 ..< limit  {
              extractSamples.append(self.samples[i])
              extractSamples.append(self.samples[self.sampleDelta + i])
            }
            if self.blockReady() != true {
              // Run extractor algorithm on these samples
              self.extractor.collectEntropy(samples: extractSamples)

              // Remove the samples we just used
              self.samples.removeSubrange(self.sampleDelta ..< (self.sampleDelta + limit) )
              self.samples.removeSubrange(0 ..< limit )
            } else {
              // Option: XOR into existing block?
            }
          }
          print("samples count: ",self.samples.count, " byte count: ", self.extractor.pos)
        }
      } else {
        self._lastFrame = f
      }
      let ts = String(format:"%.3f",Date().timeIntervalSince(tStart))
      print("Frame \(self.counter) processed in: \(ts) seconds")
    }
  }

  func getEntropy() -> [UInt8] {
    return autoreleasepool {
      if self.blockReady() {
        self.lastChi = self.extractor.chiSquare(self.blockSize)
        print("chi square:", self.lastChi)
        let entropy = self.extractor.getEntropy(count: self.blockSize)!
        if (entropy.count > 0) {
          self.totalGenerated += self.blockSize
        }
        return entropy
      }
      return [UInt8]()
    }
  }

  func reset() {
    self.samples = [Sample]()
    self.samples.reserveCapacity(self.sampleDelta*10)
    self.counter = 0
    self.totalGenerated = 0
    self.rejectedFrames = 0
    self.lastChi = 0
    self._lastFrame = nil
    self.setBlockSize()
  }
}
