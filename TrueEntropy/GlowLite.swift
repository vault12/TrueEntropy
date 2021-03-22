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

class GlowLite : Utils {
  var NaCl = Sodium()
  // Singleton
  static let shared = GlowLite()
  var relay:String?
  var client_token = [UInt8]()
  var relay_token:Data = Data()
  var h2_ct = [UInt8]()

  var zax_session_key:Data?
  var our_session_key:Box.KeyPair?
  var station_key:Box.KeyPair?

  var ready:Bool = false
  var lastSession:Date! = nil

  var pk:[UInt8] { get {
      return [UInt8](self.station_key!.publicKey)
    }
  }
  var hpk:[UInt8] { get {
      return self.h2(self.pk)
    }
  }

  override private init() {}

  func refreshSession() -> Bool
  {
    if self.relay == nil { print("no relay"); return false }

    if self.lastSession == nil || Date().timeIntervalSince(self.lastSession) > Constants.sessionRefresh {
      return self.connect(relay: self.relay!)
    }
    return self.ready
  }

  func connect(relay: String) -> Bool {
    self.ready = false
    self.relay = relay

    if relay.isEmpty || self.load_station_key() == nil { return false }

    self.client_token = randBuf(Utils.HASH_LEN)
    let start_session = self.relayRequest(call: "start_session", body: self.to_b64(self.client_token)) {
      (data: Data!, response: URLResponse!, e1: Error!) -> Void in
      if (e1 != nil ) { print("Relay start_session failure: \(e1.localizedDescription)"); return; }

      let lines = String(data: data, encoding: .utf8)!.components(separatedBy:Utils.EOL)
      if lines.count != 2 { return }
      self.relay_token = Data(base64Encoded:String(lines[0]))!
      let diff = Int(lines[1])!

      // Let's not bother relays that are too hard to reach
      if diff > 22 { return }
      self.h2_ct = self.h2(self.client_token)
      var ver_body = self.to_b64(self.h2_ct) + Utils.EOL
      var handshake:[UInt8] = self.h2(self.client_token + [UInt8](self.relay_token))
      if diff > 0 {
        var nonce = self.randBuf(Utils.HASH_LEN)
        handshake = self.h2(self.client_token + [UInt8](self.relay_token) + nonce)
        while !self.array_zero_bits(array: handshake, num_bits: diff) {
          nonce = self.randBuf(Utils.HASH_LEN)
          handshake = self.h2(self.client_token + [UInt8](self.relay_token) + nonce)
        }
        ver_body += self.to_b64(nonce)
      } else {
        ver_body += self.to_b64(handshake)
      }

      let verify_session = self.relayRequest(call: "verify_session", body: ver_body) {
        (data2: Data!, response2: URLResponse!, e2: Error!) -> Void in

        if (e2 != nil ) { print("Relay verify_session failure: %@", e2.localizedDescription); return; }

        let lines = String(data: data2, encoding: .utf8)!.components(separatedBy:Utils.EOL)
        if (lines.count != 1) { return }
        self.zax_session_key = Data(base64Encoded:String(lines[0]))

        // We have session key, now lets prove ownership of our HPK
        self.prove_hpk()
      }
      verify_session.resume()
    }
    start_session.resume()

    // few seconds to establish session or fail
    var wait = 0
    while !self.ready && wait < Constants.waitForResponse { sleep(1); wait+=1 }
    if !self.ready { return false }
    self.lastSession = Date()
    return true
  }

  //  Zax relay expects 4 lines, base64 each:
  //  1: h₂(client_token): client_token used to receive a relay session pk
  //  2: a_temp_pk : client temp session key
  //  3: nonce_outter: timestamped nonce
  //  4: crypto_box(JSON, nonce_inner, relay_session_pk, client_temp_sk): Outer crypto-text
  func prove_hpk() {
    // Line 1 : h2 of our client_token
    var body:String = self.to_b64(self.h2_ct) + Utils.EOL
    self.our_session_key = self.NaCl.box.keyPair()
    if self.our_session_key == nil { return }

    // Line 2: client side temp session key
    body += Data(bytes: self.our_session_key!.publicKey).base64EncodedString() + Utils.EOL

    // Line 3: outter nonce, which we will use to encrypt outter box
    let nonce_outter = self.make_nonce()
    body += nonce_outter.base64EncodedString() + Utils.EOL

    // Signature constructed from session handshake tokens encrypted with station HPK
    let sign = self.h2([UInt8](self.our_session_key!.publicKey) + self.relay_token + self.client_token)
    let nonce_inner = self.make_nonce()
    let ctext = self.NaCl.box.seal(
      message: sign,
      recipientPublicKey: Array(self.zax_session_key!),
      senderSecretKey: Array(self.station_key!.secretKey),
      nonce: Array(nonce_inner))!

    let inner = self.to_json(obj: [
      "pub_key":Data(self.station_key!.publicKey),
      "nonce":nonce_inner,
      "ctext":Data(ctext)])

    let msg = self.NaCl.box.seal(
      message: Array(inner),
      recipientPublicKey: Array(self.zax_session_key!),
      senderSecretKey: Array(self.our_session_key!.secretKey),
      nonce: Array(nonce_outter))!

    // Line 4: outter cipher text
    body += Data(msg).base64EncodedString()
    let prove_hpk_req = self.relayRequest(call: "prove", body: body) {
      (data: Data!, response: URLResponse!, e1: Error!) -> Void in
      if e1 == nil && (response as! HTTPURLResponse).statusCode == 200 {
        self.ready = true
      }
    }
    prove_hpk_req.resume()
  }

  func relayRequest(call:String, body:String,
                    handler:@escaping (Data?, URLResponse?, Error?) -> Void ) -> URLSessionDataTask
  {
    let sessionConfig = URLSessionConfiguration.default
    let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
    var request = URLRequest(url: URL(string: self.relay! + "/" + call)!)
    request.httpMethod = "POST"
    request.httpBody = body.data(using: .utf8)
    return session.dataTask(with: request, completionHandler: handler)
  }

  static func get_station_key() -> Box.KeyPair {
    let storage_name = "station_key_seed"
    let defaults = UserDefaults.standard
    let seed:Data
    if (defaults.object(forKey: storage_name) == nil)
    {
      seed = Data(Utils.global.randBuf())
      defaults.set(seed, forKey: storage_name)
    } else {
      seed = defaults.object(forKey: storage_name) as! Data
    }
    return Sodium().box.keyPair(seed: Array(seed))!
  }

  func load_station_key() -> Box.KeyPair? {
    self.station_key = GlowLite.get_station_key()
    return self.station_key
  }

  func make_body(_ data:[Data]) -> String {
    var b = ""
    for d in data {
      if !b.isEmpty { b += GlowLite.EOL }
      b += d.base64EncodedString()
    }
    return b
  }

  func sendFile(keyTo:String, file:[UInt8], name:String, completionHandler: @escaping (_ res: Bool) -> ()) throws {
    let keyToArray = from_b64(keyTo)
    if !self.ready { return }
    if !self.refreshSession() { return }

    autoreleasepool {
      // We will encrypt file with this symmetric key
      let cur_key = self.NaCl.secretBox.key()

      // Meta data about file to be uploaded
      let meta = [
        "name": name,
        "orig_size": String(file.count),
        "skey": Data(bytes: cur_key).base64EncodedString()
      ]

      // We encrypt metadata to destnation hpk_to from our station hpk
      // This is private communication between two hpk addresses
      let nonce = self.make_nonce()
      let ctext = self.NaCl.box.seal(
        message: Array(self.to_json(obj: meta)),
        recipientPublicKey: keyToArray,
        senderSecretKey: Array(self.station_key!.secretKey),
        nonce: Array(nonce))!

      // Encrypted file metadata
      let meta_json = [ "ctext": Data(ctext), "nonce": nonce ] as [String: Data]

      // Command is 3 lines: hpk_from, nonce, ctext of command body
      let nonce_cmd = self.make_nonce()
      let hpkTo = Data(h2(keyToArray))
      let cmd_json = self.to_json( obj: [
          "cmd": "startFileUpload",
          "to": hpkTo.base64EncodedString(),
          "metadata": String( data:self.to_json(obj: meta_json), encoding: .utf8)! ],
        extra: "\"file_size\":\(file.count)" )

      // Encrypting command. This is private communcation between
      // this station hpk and relay
      let cmd_ctext = self.NaCl.box.seal(
        message: Array(cmd_json),
        recipientPublicKey: Array(self.zax_session_key!),
        senderSecretKey: Array(self.our_session_key!.secretKey),
        nonce: Array(nonce_cmd))!

      func uploadChunk(_ n:Int, _ uploadID:String, _ chunks:Int, _ max_chunk:Int) -> URLSessionDataTask {
        return autoreleasepool {
          let top = (n+1)*max_chunk > file.count ? file.count : (n+1)*max_chunk
          let data = Data(file[n*max_chunk ..< top ])

          let (file_ctext, file_nonce) = self.NaCl.secretBox.seal(message: Array(data), secretKey: cur_key)!

          let cmd_json = self.to_json(
            obj: [
              "cmd": "uploadFileChunk",
              "uploadID": uploadID,
                "nonce": Data(bytes: file_nonce).base64EncodedString()],
            extra: "\"part\":\(n),\"last_chunk\":\(String(n == chunks - 1))" )

          let nonce_cmd = self.make_nonce()
          let cmd_ctext = self.NaCl.box.seal(
            message: Array(cmd_json),
            recipientPublicKey: Array(self.zax_session_key!),
            senderSecretKey: Array(self.our_session_key!.secretKey),
            nonce: Array(nonce_cmd))!

          let body = self.make_body([Data(self.hpk), nonce_cmd, Data(cmd_ctext), Data(file_ctext) ])

          return self.relayRequest(call: "command", body: body) {
            (data: Data!, response: URLResponse!, e: Error!) -> Void in
            // print((response as! HTTPURLResponse).statusCode)
            if (n+1) < chunks {
              uploadChunk(n+1, uploadID, chunks, max_chunk).resume()
            } else {
              completionHandler(true)
            }
          }
        }
      }

      let body = self.make_body([Data(self.hpk), Data(nonce_cmd), Data(cmd_ctext)])
      let startUpload = self.relayRequest(call: "command", body: body) {
        (data: Data!, response: URLResponse!, e: Error!) -> Void in
        if e == nil {
          autoreleasepool {
            let lines = String(data: data, encoding: .utf8)!.components(separatedBy:Utils.EOL)
            let nonce = Data(base64Encoded:String(lines[0]))!
            let ctext = Data(base64Encoded:String(lines[1]))!
            let answer = self.NaCl.box.open(
              authenticatedCipherText: Array(ctext),
              senderPublicKey: Array(self.zax_session_key!),
              recipientSecretKey: Array(self.our_session_key!.secretKey),
              nonce: Array(nonce))!

            guard let json = try? JSONSerialization.jsonObject(with: Data(answer)) as! [String:Any] else { return }

            let max_chunk = json["max_chunk_size"] as! Int - 100 // Reserve few bytes for encryption data
            let uploadID = json["uploadID"] as! String

            let chunks = 1 + file.count / max_chunk

            DispatchQueue.main.async {
              uploadChunk(0, uploadID, chunks, max_chunk).resume()
            }
          }
        }
      }
      startUpload.resume()
    }
  }
}
