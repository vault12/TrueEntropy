// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import Darwin
import Foundation

// Sample is the raw "noise" values in one RGB channel.
// Each difference between 2 frames produces 3 Samples of raw noise, one
// for each color channel.
//
// The Extractor batches up a collection of Samples, separated by a time delta to
// avoid timing correlations and used with different indexing to avoid
// locality corrleations, and then processes the raw values into uniform bytes.
class Sample {
  var samples: [Int]  // Raw values in R,G or B channel
  var count: Int { get { return self.samples.count }}
  let width: Int
  var height: Int { get { return self.count/self.width }}

  var hist: [Int]           = []
  var mean: Double          = 0
  var variance: Double      = 0
  var deviation: Double     = 0
  var min: Int              = 0
  var max: Int              = 0
  var entropy: Double       = 0
  var min_entropy: Double   = 0
  var repeat_zeroes: Double = 0

  init(_ samples: [Int], width:Int, height _: Int, hist:[Int] = [], mean:Double = 0) {
    (self.samples, self.width, self.hist, self.mean) = (samples,width,hist,mean)

    // Quick shortcut using assumption that non-0 centered samples are rejected
    // If the sample is 0-centered then a histogramm of '0' is the most common event
    if (hist.count > UInt8.max) {
      self.min_entropy = -log2( Double(hist[Int(UInt8.max)]) / Double(self.count) )
    }

    // Remove non-noise 0 values from oversatured areas which produce inprobably
    // long sequences of zero values.
    self.remove_zero_lines()
  }

  var no_stats:Bool {
    get { return self.deviation.isZero || self.entropy.isZero || self.min_entropy.isZero }
  }

  // Calculate all stats in one loop
  func do_stats() {
    var (sum,sum_sq,dcount) = (Int: 0, Int: 0, Double(self.count))

    // Do Int math first, since it is faster
    for s in self.samples {
      sum += s
      sum_sq += s * s
      if s < self.min { self.min = s }
      if s > self.max { self.max = s }
    }

    self.mean = Double(sum)/dcount
    self.variance = ( Double(sum_sq) - ( Double(sum)*Double(sum)/dcount ) ) / dcount
    self.deviation = sqrt(self.variance)

    var pa = [Double]()
    self.entropy = 0 - self.hist.reduce(0) { (r,freq) in
      if freq != 0 {
        let p=Double(freq)/Double(self.count)
        pa.append(log2(p))
        return r + p * log2(p)
      }
      return r
    }
    self.min_entropy = -pa.min()!
  }

  var key_stats : [Any] {
    get {
      if self.no_stats { self.do_stats() }
      return [ self.mean, self.variance, self.deviation,
               self.min, self.max,
               self.entropy, self.min_entropy ] }
  }

  // To avoid local correlations access samples from different
  // channels in different order
  func indexer(_ index:Int, sampleOrder:Int = 0) -> Int {
    // Indexing functions:
    // Direct usual array indexing [0,count)
    // Reverse indexes in reverse order, from the back of collection
    // Orthogonal swaps rows and coloums and goes in orthogonal direction
    func direct (_ i:Int)  -> Int { return i }
    func reverse(_ i:Int)  -> Int { return self.count - i - 1 }
    func ortho  (_ i:Int)  -> Int { return self.height * ( i % self.width) + i/self.width }
    let mappers = [direct,reverse,ortho]
    return mappers[sampleOrder % mappers.count](index)
  }

  func getSample(_ index:Int,order:Int = 0) -> Int {
    var i = self.indexer(index, sampleOrder: order)
    // If indexer sent us out of bounds, bounce it from the end of array
    while i >= self.count { i -= self.count }
    return self.samples[i]
  }

  func to_normal(_ i:Int) -> Double {
    return (Double(self.samples[i])-self.mean) / self.deviation
  }

  // Max value for given entropy
  var max_val:Double {
    get { return pow(2,floor(self.min_entropy)) }
  }

  // If two frames have the same over-bright area, it will convert to a long line
  // of zeros in tye difference sample: when the camera's brightness is maxed out,
  // there is not enough itensity value for the noise to register: 255-255 = 0.
  func remove_zero_lines(max_zeroes:Int = 7)  {
    var toRemove:[(Int,Int)] = []
    var ( range_start, range_count ) = (Int: 0, Int: 0)
    // Record zero sequences to be removed
    for i in 0 ..< self.count {
      let s = self.samples[i]
      if s == 0 && range_count == 0 { range_start = i }
      if s == 0                     { range_count += 1 }
      if s != 0 && range_count > 0 {
        if range_count > max_zeroes {
          toRemove.append( (range_start,i) )
        }
        range_count = 0
      }
    }

    let original = self.samples
    // Remove zero sequences and replace original samples with refined version
    if !toRemove.isEmpty {
      self.samples = [Int]()
      self.samples.reserveCapacity(original.count)
      var last:Int = 0
      for p in toRemove {
        self.samples.append(contentsOf: original[last..<p.0])
        last = p.1
      }
      self.samples.append(contentsOf: original[last..<original.count])
    }

    let zRemoved = original.count - self.count
    let zRemovedPct = Double(100 * zRemoved) / Double(original.count)
    self.repeat_zeroes = zRemovedPct
    print("removed \(String(format:"%-7d", zRemoved)): \(String(format:"%02.2f",zRemovedPct))% repeat zeroes")
  }
}
