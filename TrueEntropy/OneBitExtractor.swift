// DO NOT USE IN PRODUCTION!
// DO NOT USE IN PRODUCTION!
// DO NOT USE IN PRODUCTION!
//
// This extractor is only to demonstrate the distribution
// of a "naive" extractor that doesn't take into account
// a biased entropy source.
//
// Unlike the Von Neumann extractor, this extractor simply
// outputs one bit depending if the noise value is above or below 0.

import Foundation

// DO NOT USE IN PRODUCTION!
class OneBitExtractor: ExtractAlgorithm {

  let max_samples = 8
  let powers:[UInt32]

// DO NOT USE IN PRODUCTION!
  init() {
    self.powers = (0..<self.max_samples).map { return UInt32(1<<$0) }
  }

// DO NOT USE IN PRODUCTION!
  // We don't use 0, so skip all 0 values
  func  filterSamples(samples:[Int]) -> [Int] { return samples.filter { return $0 != 0 } }

// DO NOT USE IN PRODUCTION!
  var   minimalSamples:Int { get { return self.max_samples } }

// DO NOT USE IN PRODUCTION!
  func  encode(samples:[Int]) -> (newBits:UInt32, size:Int) {
    if samples.count < 1 || samples.count > self.max_samples { return (0,0) }
    let res = samples.enumerated().reduce(0) { (res:UInt32, en) in
      let (i,s) = en
      return s > 0 ? res + self.powers[i] : res
    }
    return (res,samples.count)
  }
}

// DO NOT USE IN PRODUCTION!
// DO NOT USE IN PRODUCTION!
// DO NOT USE IN PRODUCTION!
