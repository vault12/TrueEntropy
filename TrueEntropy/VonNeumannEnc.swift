// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import Foundation

// We implement the ExtractAlgorithm with a recurisve VonNeumann extractor
// See: http://www.eecs.harvard.edu/~michaelm/coinflipext.pdf

class VonNeumannEncoder: ExtractAlgorithm {
  var _max_bits:Int = 2

  // How many bits we can use to encode incoming values with a high bias
  // That can be determined by the operator based on current camera view.
  // 1 bit is the most safe, 3 bits work in perfect camera conditions.
  var  max_bits:Int {
    get { return self._max_bits }
    set {
      self._max_bits = newValue > 8 ? 8 : newValue
      VonNeumannEncoder.convBits = [(UInt32,Int)]()
      prepareEncoder()
    }
  }

  var range:Int     { get { return 1 << self.max_bits }} // 2^bits
  var min:Int       { get { return -self.range/2 } }
  var max:Int       { get { return self.range/2 } }
  var max_bytes:Int { get { return VonNeumannEncoder.byteDepthPerBits[self.max_bits] }}
  var minimalSamples:Int { get { return self.max_bytes }}

  // For longer input byte sequences extractor consumes, we will need
  // a larger and larger lookup table. This table converts the given bit length
  // to number of input bytes that keeps the lookup table below 1-2mb.
  // 1-2 bits can handle 8 bytes input sequences, and decreases
  // input bytes starting from 3 bit encoder.
  static var convBits  = [(UInt32,Int)]()

  // 1-bit encoder can take 8 bytes of imput, since its only 2^8 values
  // 8-bit encoder can take 1 byte of imput since it uses every bit
  // Other values are calculated to keep memory footprint around 1-2mb
  static let byteDepthPerBits = [ 8, 8, 8, 6, 5, 4, 3, 2, 1]

  init(max_bits:Int = 2) {
    self.max_bits = max_bits
  }

  // Input value to index of that value in conversion row
  func val2idx(_ v:Int) -> Int {
    var r = v % self.range
    if r < 0 { r = self.range + r }
    return r
  }

  // Position of conversion value for 'sequence' of bytes is caclcuated
  // as exponential combination of position for each input byte
  func sequenceIdx(_ vals:[Int]) -> Int {
    var power:Int = 1
    let v:[Int] = vals.count > self.max_bytes ? [Int](vals[0..<self.max_bytes]) : vals
    return v.reduce(0) { (res, vl) in
      let t = res + power * val2idx(vl)
      power *= self.range
      return t
    }
  }

  // VonNeumann encoding is constant - for the same sequence of input bytes it will
  // always output the same sequence of bits (including 0-length sequences when we
  // simply ignore input). That means we can pre-calculate a full conversion table
  // in advance, and run convertor as simple table value look up later.
  func prepareEncoder() {
    // Same conversion table is the same for all instances
    if VonNeumannEncoder.convBits.count > 0 { return }

    // The recursive VN algorith
    func convert(_ a:[Bool]) -> [Bool] {
      var res = [Bool]()
      var leftOver = [Bool]()
      var leftOver2 = [Bool]()
      for i in 0..<(a.count/2) {
        let (v1,v2) = (a[2*i],a[2*i+1])
        // Classic VN conversion
        if !v1 &&  v2 { res.append(true) }
        if  v1 && !v2 { res.append(false) }

        // Convert 1,1 and 0,0 into 1 and 0 in recursion buffer
        if  v1 &&  v2 { leftOver.append(true) }
        if !v1 && !v2 { leftOver.append(false) }

        // Convert generating position bits in second buffer
        if  v1 ==  v2 { leftOver2.append(true) }
        if  v1 !=  v2 { leftOver2.append(false) }
      }

      // Run VN recursion over two temp buffers
      if leftOver.count>=2 { res.append(contentsOf: convert(leftOver)) }
      if leftOver2.count>=2 { res.append(contentsOf: convert(leftOver2)) }
      return res
    }

    func fixed_bits(_ i:Int) -> String {
      let b = String(i, radix:2)
      return String(repeating:"0", count: self.max_bits - b.count) + b
    }

    let bits:[[Bool]] = (0 ..< self.range ).map {
      let s = fixed_bits($0)
      return s.map { Bool(String($0) == "1") }
    }

    // Lets record all possible sequences of values as arrays of Bool
    // into a `sequence` table
    var sequence:[[Bool]] = []
    func recurse_bits(depth:Int, _ slice: [Bool]) {
      for b in bits {
        var buffer = [Bool](slice)
        buffer.append(contentsOf: b)
        if depth == 0 { sequence.append(buffer) }
        if depth > 0  { recurse_bits(depth: depth - 1, buffer) }
      }
    }
    recurse_bits(depth: self.max_bytes - 1, [])

    // Now we have all possible sequences. Lets VN convert them from biased
    // bits to uniform bits.
    let convTable = sequence.map { convert($0) }

    // Finally, lets convert these uniform [Bool] arrays into
    // final values of encoder as UInt32
    VonNeumannEncoder.convBits = convTable.map { b in
      var r:UInt32 = 0
      b.enumerated().forEach { if $1 { r |= (1<<$0) }}
      return (r, b.count)
    }

    // That's it! Now convTable is full of final conversion values
    // for any byte sequence of length self.max_bytes. sequenceIdx()
    // can find position of any input sequence to converted value
  }

  // VN doesn't require to reject any samples. Some sequences may just not
  // produce any output.
  func filterSamples(samples:[Int]) -> [Int] {
    return samples
  }

  // Conversion of raw noise values is simply a table lookup in convBits
  func encode(samples:[Int]) -> (newBits:UInt32, size:Int) {
    if samples.count < self.max_bytes { return (0,0) }
    return VonNeumannEncoder.convBits[sequenceIdx(samples)]
  }
}
