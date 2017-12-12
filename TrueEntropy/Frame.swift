// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import Foundation
import AVFoundation

// Frame is one video frame with all the RGB pixels in kCVPixelFormatType_32BGRA
// format as UInt32 value.
// A Key functionality of the Frame class is the overloaded '-' operator that
// alows us to get an array of 3 Samples (one for each RGB channel) of the difference
// between 2 frames.


class Frame {
  var width:  Int
  var height: Int
  var size:   Int
  var pixels: [UInt32]
  var hist:   [[Int]]

  init(new_pixels: [UInt32], width w: Int,height h: Int ) {
    self.width = w
    self.height = h
    self.size = w * h
    self.pixels = new_pixels
    self.hist = [[Int](),[Int](),[Int]()]
  }

  // This is the main constructor that takes a pixel buffer of live video session
  // and copies bytes into self.pixels
  convenience init(pixelBuffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    let w = CVPixelBufferGetWidth(pixelBuffer)
    let h = CVPixelBufferGetHeight(pixelBuffer)
    let size = w * h

    let base = CVPixelBufferGetBaseAddress(pixelBuffer)!.bindMemory(to:UInt32.self,capacity:size)
    let mem_pixels = UnsafeBufferPointer(start: base, count: size)
    let pixels = [UInt32](mem_pixels)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)

    self.init(new_pixels:pixels, width:w, height:h)
  }

  // Since each pixel is UInt32 in kCVPixelFormatType_32BGRA format,
  // we need accessors to get byte of specific color

  // Access by value of pixel
  func R(_ p:UInt32)  -> UInt32 { return (p & 0x00FF0000) >> 16 }
  func G(_ p:UInt32)  -> UInt32 { return (p & 0x0000FF00) >> 8  }
  func B(_ p:UInt32)  -> UInt32 { return (p & 0x000000FF) >> 0  }

  // Access by index of pixel in self.pixels
  func R(_ i:Int)     -> UInt32 { return R(self.pixels[i]) }
  func G(_ i:Int)     -> UInt32 { return G(self.pixels[i]) }
  func B(_ i:Int)     -> UInt32 { return B(self.pixels[i]) }

  // Convert pixel `i` to Array of RGB values
  func RGB(_ i:Int) -> [UInt32] {
    let p = self.pixels[i]
    return [R(p),G(p),B(p)]
  }

  func calcHistogramm() {
    // Init RGB histograms to 0
    self.hist=[[Int](repeating: 0, count: Int(UInt8.max) + 1 ),
               [Int](repeating: 0, count: Int(UInt8.max) + 1 ),
               [Int](repeating: 0, count: Int(UInt8.max) + 1)]
    for ix in 0..<self.pixels.count {
      RGB(ix).enumerated().forEach { (i,px) in
        self.hist[i][Int(px)] += 1 }
    }
  }

  private var _meanRGB: [Double]!
  var meanRGB: [Double] {
    get {
      if (_meanRGB != nil) {
        return self._meanRGB
      } else {
        var avg : [UInt32] = [0,0,0]
        (0..<self.size).forEach { RGB($0).enumerated().forEach { avg[$0]+=$1 }}
        self._meanRGB = avg.map { Double($0)/Double(self.size) }
        return self._meanRGB
      }
    }
  }
}

// Convert difference between 2 frames into an array of 3 Samples for
// each RGB channel.
//
// Because this is resource intensive - the loop is going over every
// pixel in the frame - we will calculate all the statistcs we will need
// later at the same time, and provide these values to Sample.

func - (left: Frame, right:Frame) -> [Sample]! {
  if  left.width  != right.width || left.height       != right.height ||
      left.size   != right.size  || left.pixels.count != right.pixels.count {
    return nil
  }

  var res:[Sample]!
  autoreleasepool {
    let size = left.size
    let maxColor = Int(UInt8.max)

    // Values of Samples we creating
    var s =    [[Int](repeating: 0, count: size),
                [Int](repeating: 0, count: size),
                [Int](repeating: 0, count: size) ]

    // Histogramm of difference - now range is doubled
    // since difference could be +/- 255 (pixels can only
    // be 0-255)
    var hist = [[Int](repeating: 0, count: 2*maxColor + 1),
                [Int](repeating: 0, count: 2*maxColor + 1),
                [Int](repeating: 0, count: 2*maxColor + 1)]

    var mean = [Int](repeating:0,count:3)

    let masks:[(UInt32,UInt32)] = [ (0x00FF0000,16), (0x0000FF00,8), (0x000000FF,0)]

    for i in 0..<size {
      let pl = left.pixels[i]  // pixel left
      let pr = right.pixels[i] // pixel right
      for j in (0..<3) {
        let (mask, shift) = masks[j]
        let diff = Int((pl & mask) >> shift) - Int((pr & mask) >> shift)
        s[j][i] = diff
        mean[j] += diff
        hist[j][maxColor + diff] += 1 // difference '0' goes into slot 255
      }
    }
    res = (0..<3).map {
      Sample(s[$0], width: left.width, height: left.height,
             hist: hist[$0], mean: Double(mean[$0])/Double(size)) }
  }
  return res  // Sample[3]
}
