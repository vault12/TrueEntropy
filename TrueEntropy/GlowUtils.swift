// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT
//
// GlowLite is an extremely light-weight implementation of the Glow client
// library to create sessions with a Zax crypto relay to upload files.
// You should use the full Glow library for any sort of significant production
// use: https://github.com/vault12/glow

import Foundation
import Sodium
import Clibsodium

class Utils {
  static let HASH_BLOCK:Int = 64
  static let HASH_LEN:Int = 32
  static let NONCE_LEN:Int = 24
  static let EOL = "\r\n"
  // to use as a singleton
  static let global = Utils()

  // Base64 conversions
  func to_b64(_ d:[UInt8]) -> String {
    return Data(d).base64EncodedString()
  }
  func from_b64(_ base64String: String) -> [UInt8] {
    if let nsdata = NSData(base64Encoded: base64String, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
      var bytes = [UInt8](repeating: 0, count: nsdata.length)
      nsdata.getBytes(&bytes, length: nsdata.length)
      return bytes
    }
    return [UInt8]()
  }

  // Random buffer
  func randBuf(_ n:Int = HASH_LEN) -> [UInt8] {
    var res = [UInt8](repeating:0, count: n)
    arc4random_buf(UnsafeMutableRawPointer(&res),n)
    return res
  }

  // Random base64 string
  func randStr(_ n:Int = HASH_LEN) -> String {
    return to_b64(randBuf(n))
  }

  // Double hash of Zax/Glow
  // Zero out initial sha256 block, and double hash 0-padded message
  // See http://cs.nyu.edu/~dodis/ps/h-of-h.pdf
  func h2(_ data:[UInt8]) -> [UInt8] {
    var h1 = [UInt8](repeating:0, count:Utils.HASH_LEN)
    var h2 = [UInt8](repeating:0, count:Utils.HASH_LEN)

    var pad_data = [UInt8](repeating:0, count:Utils.HASH_BLOCK)
    pad_data.reserveCapacity(Utils.HASH_BLOCK + data.count)
    pad_data.append(contentsOf: data)

    crypto_hash_sha256(&h1, pad_data, UInt64(pad_data.count))
    crypto_hash_sha256(&h2, h1, UInt64(h1.count))

    return h2
  }


  // NaCl nonce with timestamp. Zax checks recency of all nonces
  func make_nonce() -> Data {
    var res = self.randBuf(Utils.NONCE_LEN)
    res.replaceSubrange((0..<8), with: repeatElement(0, count: 8))
    let tnow = UInt32(Date().timeIntervalSince1970)
    let ts = (0..<4).reversed().map { UInt8(UInt32( floor( Double(tnow) / pow(Double(256),Double($0)))) % 256) }
    res.replaceSubrange((4..<8), with: ts)
    return Data(res)
  }

  func first_zero_bits(_ byte:UInt8,_ n:Int) -> Bool {
    return byte == ((byte >> n) << n)
  }
  func array_zero_bits(array:[UInt8], num_bits:Int) -> Bool
  {
    if (num_bits <= 0) { return true }
    var rmd = num_bits
    for i in 0..<(1 + num_bits / 8) {
      let a = array[i]
      if rmd > 8 {
        rmd -= 8
        if a != 0 { return false }
      } else {
        return first_zero_bits(a, rmd)
      }
    }
    return false
  }

  // from hash objects into JSON as Data
  func to_json(obj:Dictionary<String,Data>) -> Data {
    return self.to_json(obj: obj.mapValues() { return $0.base64EncodedString() })
  }

  // Pass extra custom string when data doesn't feet Swift hash
  func to_json(obj:Dictionary<String,String>, extra:String? = nil) -> Data {
    var res = "{"
    for (name, val) in obj {
      if val.starts(with: "{") {
        res += "\"\(name)\":\(val),"
      }
      else {
        res += "\"\(name)\":\"\(val)\","
      }
    }
    if (extra != nil ) { res += extra! + "," }
    res.removeLast(1)
    res += "}"
    return res.data(using: .utf8)!
  }
}
