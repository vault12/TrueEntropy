// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import Foundation

// Interface for extraction algoirthm
protocol ExtractAlgorithm {
  // Encode raw values (Int) into 'size' number of newBits, set inside UInt32
  func  encode(samples:[Int]) -> (newBits:UInt32, size:Int)

  // Reject specific raw sample values if algorithm requires it
  func  filterSamples(samples:[Int]) -> [Int]

  // Minimal number of sample algorith needs to process as batch
  var   minimalSamples:Int { get }
}

// Extractor manages the conversion of raw sample values into uniform entropy bit
// delegating specific conversion to ExtractAlgorithm instance
class Extractor {
  static let shared = Extractor()
  var result:[UInt8]
  var capacity:Int { get { return self.result.capacity }}
  var pos:Int = 0         // Pointer to full byte we filling out inside result array
  var bitPos:Int = 0      // Position inside the byte we filling out
  var algorithm:ExtractAlgorithm
  var chiSquareLimit:Double = 0

  var debugOutput:Bool = false  // Enable this for low level debug info
  var debugCount:Int = 100
  var debug:Bool { get { return debugOutput && self.pos<self.debugCount } }

  private init() {
    self.result = [UInt8](repeating:0, count: Constants.extractorCapacity)
    self.algorithm = VonNeumannEncoder(max_bits: UserDefaults.standard.integer(forKey: "speed"))
    self.setChiSquareLimit()
  }

  func setMaxBits(_ mBits:Int = UserDefaults.standard.integer(forKey: "speed")) {
    self.algorithm = VonNeumannEncoder(max_bits: mBits)
  }

  func setChiSquareLimit() {
    if UserDefaults.standard.bool(forKey: "x2_limit_enabled") {
      self.chiSquareLimit = UserDefaults.standard.double(forKey: "x2_limit")
    } else {
      self.chiSquareLimit = 0
    }
  }

  func checkCapacity() {
    // If we have only 10% left, grow result buffer by half
    if self.pos >= (self.capacity - self.capacity/10) {
      let oldCap = self.capacity
      let capacity = self.capacity + self.capacity/2
      self.result.reserveCapacity(capacity)
      self.result.append(contentsOf: repeatElement(0, count: capacity - oldCap))
    }
  }

  // Encode batch of raw Int values into bits in `result` buffer
  func encode(_ v:[Int]) {
    // Internal reporting of encoder in debug mode
    func report(_ action:String, byte:UInt32, _ values:[Int] = [], _ size:Int = 0) {
      if !self.debug { return }
      if action == "encoding" {
        print("encoding \(values) with \((byte,String(byte,radix:2),size))")
      } else {
        print("\(action) \(byte)=\(String(byte,radix:2)) at [\((self.pos,self.bitPos))]")
      }
    }

    // Move to encoding next byte of output
    func nextByte(_ byte:UInt32) {
      if self.bitPos >= 8 {
        self.pos += 1
        self.bitPos -= 8
        self.checkCapacity()
        self.result[pos] = UInt8( (byte & 0xFF00) >> 8 )
        report("new byte starts: ", byte: UInt32(self.result[pos]))
        nextByte(byte >> 8)
      }
    }

    // Let algorithm reject unwanted values
    let values:[Int] = self.algorithm.filterSamples(samples: v)

    // Encode 'size' count of new_bits using algorithm
    let (new_bits, size) = self.algorithm.encode(samples: values)
    report("encoding", byte: new_bits, values, size)

    // If we got non-zero size bits sequence, lets store it
    if size > 0 {
      // The byte we recorded so far
      var byte = UInt32(self.result[pos]);  report("we have:", byte: byte)
      // Add new bits
      byte |= (new_bits << self.bitPos)
      // Crop at byte boundary
      self.result[self.pos] = UInt8( byte & 0x00FF)
      self.bitPos += size;                  report("now it is", byte: UInt32(self.result[pos]))

      // Start next byte with remainder if current byte is full
      nextByte(byte)
    }
  }

  // We have a batch of raw Samples, which we need to access with variable
  // indexing (to prevent locality correlations) and get batches of raw Int
  // values of noise. 'order' value 0,1,2 determines which indexer is used.
  func collectEntropy(samples:[Sample]) {
    let c = samples.map {$0.count}.min()!
    for i in 0..<c {
      let data:[Int] = samples.enumerated().map { e in
        let (order, sample) = e
        return sample.getSample(i, order: order)
      }
      self.encode(data)
    }
  }

  func reset() {
    self.pos = 0
    self.bitPos = 0
    self.result = [UInt8](repeating:0, count:self.capacity)
    self.setMaxBits()
    self.setChiSquareLimit()
  }

  // Get 'count' of bytes from buffer and remove that range from buffer memory
  func getEntropy(count:Int) -> [UInt8]! {
    if count > self.pos { return nil }
    var entropy = [UInt8](self.result[0..<count])
    // return empty block if x2 does not fit the limit
    if (self.chiSquareLimit > 0) && (self.chiSquare(count) > self.chiSquareLimit) {
      entropy = [UInt8]()
    }
    self.result.removeSubrange(0..<count)
    self.pos -= count
    self.result.append(contentsOf: repeatElement(0, count: self.capacity-self.result.count))
    return entropy
  }

  func chiSquare(_ count:Int = 0) -> Double {
    let limit = count == 0 ? self.pos - 1 : count
    let est = Double(limit)/256
    var values = [UInt32](repeating:0, count: 256)
    self.result[0..<limit].forEach { values[Int($0)] += 1 }
    return values.reduce(0) { (res:Double,u:UInt32) in
      let d = Double(u) - est
      return res + d*d/est
    }
  }
}
