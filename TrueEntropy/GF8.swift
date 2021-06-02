//  GF8.swift
// Copyright (c) 2017-2021 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

// Implementation of GF(8) field ops
// http://homepages.math.uic.edu/~leon/mcs425-s08/handouts/field.pdf

import Foundation

class GF8 {
  
  enum GF8Error: Error {
    case ArrayToShortForABC
  }
  
  static func add(_ a: UInt8, _ b:UInt8) -> UInt8 { return a ^ b; }
  static func sub(_ a: UInt8, _ b:UInt8) -> UInt8 { return add(a, b); }
  
  static func mul(_ a: UInt8, _ b:UInt8) -> UInt8 {
    if (a == 0 || b == 0) { return 0; }
    if (a == 1) { return b }
    if (b == 1) { return a }
    return MUL[Int(a)][Int(b)];
  }
  
  static private let MUL: [[UInt8]] = [
    [0,0,0,0,0,0,0,0], // 0:   0 x b
    [0,1,2,3,4,5,6,7], // 1:   1 x b
    [0,2,4,6,3,1,7,5], // x:   2 x b
    [0,3,6,5,7,4,1,2], // x+1: 3 x b
    
    [0,4,3,7,6,2,5,1], // x^2:     4 x b
    [0,5,1,4,2,7,3,6], // x^2+1:   5 x b
    [0,6,7,1,5,3,2,4], // x^2+x:   6 x b
    [0,7,5,2,1,6,4,3]  // x^2+x+1: 7 x b
  ];
  
  // Single run of RNG extractor a * b + c over GF(2^3)
  // https://www.boazbarak.org/Papers/msamples.pdf
  static func abc(_ a: UInt8, _ b:UInt8, _ c:UInt8) -> UInt8 {
    return add(mul(a,b),c)
  }
  
  static func abc_reduceA(x: inout [UInt8]) -> [UInt8] {
    if (x.count < 3) { return [] }
    var res = [UInt8]()
    res.reserveCapacity(1 + x.count/3)
    while (x.count >= 3) {
      let (a,b,c) = (x.removeFirst(), x.removeFirst(), x.removeFirst())
      res.append(abc(a,b,c))
    }
    return res
  }
  
  static func abc_A(x: inout [UInt8]) throws -> UInt8 {
    guard x.count >= 3 else { throw GF8Error.ArrayToShortForABC }
    while (x.count >= 3) { x = abc_reduceA(x: &x) }
    return x.first!
  }
  
}
