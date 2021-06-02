// Copyright (c) 2017-2021 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT

import XCTest
@testable import TrueEntropy

class TrueEntropyTests: XCTestCase {
    func testAssocRuleGF8() throws {
      for _ in 0...10000 {
        let (a,b,c) = (UInt8(arc4random() % 8),
                       UInt8(arc4random() % 8),
                       UInt8(arc4random() % 8))
        // a*(b+c) = ab + ac
        XCTAssertEqual(GF8.mul( a, GF8.add(b,c) ),
                       GF8.add( GF8.mul(a,b), GF8.mul(a,c)))
      }
      
      for _ in 0...10000 {
        let (a,b,c) = (UInt8(arc4random() % 8),
                       UInt8(arc4random() % 8),
                       UInt8(arc4random() % 8))
        // a*(b-c) = ab - ac
        XCTAssertEqual(GF8.mul(a, GF8.sub(b,c)),
                       GF8.sub(GF8.mul(a,b), GF8.mul(a,c)))
      }
    }
  
  func testABCGen() throws {
    var numbers:[UInt8] = Array(0...7)
    // 0 * 1 + 2 = 2
    // 3 * 4 + 5 = 7 + 5 = 7 ^ 5 = 2
    XCTAssertEqual(GF8.abc_reduceA(x: &numbers), [2,2])

    numbers = Array((0...7).reversed()); numbers += [7] // Now 9 values
    var n2 = numbers

    // 7 * 6 + 5, 4 * 3 + 2, 1*0 + 7 = 4 ^ 5, 7 ^ 2 , 7
    XCTAssertEqual(GF8.abc_reduceA(x: &numbers),[1,5,7])

    // 1 * 5 + 7 = 5 ^ 7 = 2
    XCTAssertEqual(try! GF8.abc_A(x: &n2), 2)
  }
  
  func testABCGenShortArrayException() throws {
    var shortA:[UInt8] = [1,2]
    XCTAssertThrowsError(try GF8.abc_A(x: &shortA)) { error in
      XCTAssertEqual(error as? GF8.GF8Error, .ArrayToShortForABC)
    }
  }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
  
//  override func setUpWithError() throws {
//      // Put setup code here. This method is called before the invocation of each test method in the class.
//  }
//
//  override func tearDownWithError() throws {
//      // Put teardown code here. This method is called after the invocation of each test method in the class.
//  }

}
