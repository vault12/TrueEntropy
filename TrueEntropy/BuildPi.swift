// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

// This is a toy class you can use to endlessly consume entropy
// to calculate the number Pi using Monte-Carlo method. MC is not
// a very efficient way to calculate Pi, because the error function
// diminishes in proportion to the root of the number of samples.
// Practically it means that at a constant generation speed, you
// get the first 5 digits in a few hours, the next digit will take 15 days,
// and the digit after that 1500 days!
// There are far more efficinet ways to calculate Pi.

import Foundation

class BuildPi {
  let maxU = NSDecimalNumber(mantissa: UInt64(UInt32.max),
                             exponent: 0,
                             isNegative: false).decimalValue
  var curPi:Decimal = 0
  var inside:Decimal = 0
  var total:Decimal = 0

  var entSource:EntropyCollector

  init(entropySource:EntropyCollector) {
    self.entSource = entropySource
  }

  func updatePi() {
    func fromByteArray<T>(value: [UInt8],_ newT: T.Type) -> T {
      var res:T!
      value.withUnsafeBytes { res = $0.load(as: newT) }
      return res
    }
    func getDecimal(_ xa:[UInt8]) -> Decimal {
      let xu = UInt64(fromByteArray(value: xa, UInt32.self))
      return  NSDecimalNumber(mantissa: xu, exponent: 0, isNegative: false).decimalValue / self.maxU
    }

    let vals = self.entSource.getEntropy()
    for i in stride(from: 0, to: vals.count, by: 8) {
      let x = getDecimal([UInt8](vals[(i+0)..<(i+4)]))
      let y = getDecimal([UInt8](vals[(i+4)..<(i+8)]))
      if x * x + y * y < 1 { self.inside += 1 }
      self.total += 1
    }
    self.curPi = 4 * self.inside / self.total
  }
}
