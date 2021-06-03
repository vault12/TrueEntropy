//  GF8.swift
// Copyright (c) 2017-2021 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

// Recursive RNG extractor a * b + c over GF(2^3)
// https://www.boazbarak.org/Papers/msamples.pdf

import Foundation

class ABCExtractor: ExtractAlgorithm {
  
  let recursionLevels: UInt8  // Level 1 recursion is single a*b+c run
  var quantizedSamples: [UInt8] = []
  
  init(recursion:UInt8 = 5) {
    self.recursionLevels = recursion
    print("Recursion set at ", self.recursionLevels)
    self.reserveQuantCapacity()
    GF8.createLookup()
  }
  
  func reserveQuantCapacity() {
    self.quantizedSamples.reserveCapacity(self.minimalSamples + 1000)
  }
  
  // Minimal number of raw data values algorith needs to process as batch
  // Since we recurse 3 numbers into one, each level is power of 3
  // Need 9 numbers to produce 1 final output at L2, 27 for L3, etc.
  var   minimalData:Int { get {
    return Int(pow(3.0,Double(self.recursionLevels)))
  }}
  
  // Number of samples added per single run. Typical
  // values should be in 3 to 27 range since we working
  // with powers of 3
  var   minimalSamples:Int { get { return 12 }}
  
  // Convert raw noise samples, usually in +/- 30 something range,
  // but occasionally all the way up to +/- 255 into extracted random bits.
  // Since we using recursive ABC over GF8 the output is always a
  // single number in GF8, meaning its 3 bits of entropy in 2^3 range
  func encode(samples:[Int]) -> (newBits:UInt32, size:Int) {
    // Quantize into [0,7] range for GF(8)
    self.quantizedSamples.append( contentsOf:
      // Natural zero diff are often camera artefact and has no entropy
      samples.filter() { $0 != 0 }
        .map() {
          if ($0 > 0) { return UInt8( $0 % 8 ) }
          else { return UInt8(abs(249 + $0) % 8) }
          // In this mapping common natural "-1" will become new 0
          // since we removing all natural ones
         }
        )
    
    if (self.quantizedSamples.count < self.minimalData ) {
      // No entropy bits until we fill out recursion array
      return (0,0)
    }
    
    let res = try? GF8.abc_A(&quantizedSamples)
    self.quantizedSamples.removeAll()
    self.reserveQuantCapacity()
    
    // If recursion worked, res has our GF8 random number
    // and we return it as 3 bits of entropy
    return res != nil ? (UInt32(res!),3) : (0,0)
  }
  
  // ABC doesn't require to reject any samples.
  func filterSamples(samples:[Int]) -> [Int] {
    return samples
  }
}
