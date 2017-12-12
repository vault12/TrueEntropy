// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT
//
// Settings screen (initial)

import UIKit
import AVFoundation

class SettingsController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
  @IBOutlet weak var speed1: UIButton!
  @IBOutlet weak var speed2: UIButton!
  @IBOutlet weak var speed3: UIButton!
  @IBOutlet weak var speedLabel: UILabel!

  @IBOutlet weak var delivery1: UIButton!
  @IBOutlet weak var delivery2: UIButton!

  @IBOutlet weak var relayURL: UITextField!
  @IBOutlet weak var recipientAddress: UITextView!
  @IBOutlet weak var recipientAddressPlaceholder: UITextField!

  @IBOutlet weak var airdropSettings: UIView!
  @IBOutlet weak var networkSettings: UIView!
  @IBOutlet weak var csv: UISwitch!
  @IBOutlet weak var devicePK: UILabel!

  var defaults = UserDefaults.standard
  var buttons1: Array<UIButton> = []
  var buttons2: Array<UIButton> = []

  var speedLabels = [
    1: "1 bit per pixel, low bandwidth and reliable even with poor camera view.",
    2: "2 bits per pixel, balanced.",
    3: "3 bits per pixel. High bandwidth generation, must have calibrated camera view. High risk of biased output in bad conditions!"
  ]

  override func viewDidLoad() {
    buttons1 = [speed1, speed2, speed3]
    buttons2 = [delivery1, delivery2]

    defaults.register(defaults: [
      "speed": 2,
      "delivery": "airdrop",
      "upload_csv": false,
      "block_size": 3, // enum, 1MB - see AdvancedController
      "block_amount": 3,
      "block_amount_unlimited": false,
      "relay": "https://zax-test.vault12.com",
      "recipient": "",
      "x2_limit": 330,
      "x2_limit_enabled": false
    ])

    _setSpeed(res: defaults.integer(forKey: "speed"))
    _setDelivery(res: defaults.string(forKey: "delivery")!)
    csv.setOn(defaults.bool(forKey: "upload_csv"), animated: false)

    relayURL?.delegate = self
    relayURL.text = defaults.string(forKey: "relay")

    recipientAddress?.delegate = self
    recipientAddress.textContainerInset = .zero
    recipientAddress.textContainer.lineFragmentPadding = 0
    recipientAddress.text = defaults.string(forKey: "recipient")
    recipientAddressPlaceholder.isHidden = recipientAddress.text.count > 0

    devicePK.text = GlowLite.get_station_key().publicKey.base64EncodedString()

    for btn in (buttons1 + buttons2) {
      btn.layer.borderWidth = 1
      btn.layer.borderColor = UIColor.white.cgColor
      btn.layer.cornerRadius = 3
    }

    // hide top title on small screens
    if UIScreen.main.bounds.height < 600 {
      for constraint in self.view.constraints {
        if constraint.identifier == "topMargin" {
          constraint.constant = -25
        }
      }
    }

    clearCache()

    super.viewDidLoad()
  }

  @IBAction func btnClick(btn: UIControl) {
    switch btn {
      case speed1:
        _setSpeed(res: 1)
      case speed2:
        _setSpeed(res: 2)
      case speed3:
        _setSpeed(res: 3)
      case delivery1:
        _setDelivery(res: "airdrop")
      case delivery2:
        _setDelivery(res: "network")
      case csv:
        defaults.set(csv.isOn, forKey: "upload_csv")
      default:
        return
    }
  }

  private func _setSpeed(res: Int) {
    for button in buttons1 {
      button.layer.backgroundColor = UIColor.black.cgColor
      button.setTitleColor(UIColor.white, for: .normal)
    }

    speedLabel.text = speedLabels[res]

    var btn: UIButton

    switch res {
      case 1:
        btn = speed1
      case 2:
        btn = speed2
      case 3:
        btn = speed3
      default:
        return
    }

    btn.layer.backgroundColor = UIColor.white.cgColor
    btn.setTitleColor(UIColor.black, for: .normal)

    defaults.set(res, forKey: "speed")
  }

  private func _setDelivery(res: String) {
    for button in buttons2 {
      button.layer.backgroundColor = UIColor.black.cgColor
      button.setTitleColor(UIColor.white, for: .normal)
    }

    var btn: UIButton

    switch res {
      case "airdrop":
        btn = delivery1
        networkSettings.isHidden = true
        airdropSettings.isHidden = false
      case "network":
        btn = delivery2
        networkSettings.isHidden = false
        airdropSettings.isHidden = true
      default:
        return
    }

    btn.layer.backgroundColor = UIColor.white.cgColor
    btn.setTitleColor(UIColor.black, for: .normal)

    defaults.set(res, forKey: "delivery")
  }

  func textViewDidChange(_ textView: UITextView) {
    recipientAddressPlaceholder.isHidden = textView.text.count > 0
    defaults.set(recipientAddress.text, forKey: "recipient")
  }

  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if (text == "\n") {
      textView.resignFirstResponder()
    }
    return true
  }

  @IBAction func showLoader(_ sender: Any) {
    let overlayView = UIView(frame: UIScreen.main.bounds)
    overlayView.tag = 1000
    overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    activityIndicator.center = overlayView.center
    overlayView.addSubview(activityIndicator)
    activityIndicator.startAnimating()
    self.view.addSubview(overlayView)

    if defaults.string(forKey: "delivery") == "network" {
      DispatchQueue.global(qos: .default).async {
        let relay = self.defaults.string(forKey: "relay")
        let pk = self.defaults.string(forKey: "recipient")

        if (relay?.count == 0 || pk?.count == 0) {
          self.showError("Missing network settings",
                    "Please set a valid Zax relay URL and recipient public key to upload the entropy")
          return
        }

        if (Utils.global.from_b64(pk!).count != Utils.HASH_LEN) {
          self.showError("Invalid recipient",
                    "Please make sure that destination public key is a valid base64-encoded \(Utils.HASH_LEN) bytes hash")
          return
        }

        if !GlowLite.shared.connect(relay: relay!) {
          self.showError("Network Error", "Zax relay not responding or not found. Please check whether provided URL is valid")
          return
        }

        self.goToGenerator()
      }
    } else {
      goToGenerator()
    }
  }

  func goToGenerator() {
    AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
      if response {
        DispatchQueue.main.async {
          self.performSegue(withIdentifier: "goToCamera", sender: nil)
        }
      } else {
        let alert = UIAlertController(title: "Camera permission",
                                      message: "TrueEntropy needs to access the camera. Please allow it in Settings to continue.",
                                      preferredStyle: UIAlertControllerStyle.alert)

        alert.addAction(UIAlertAction(title: "Yes",
                                      style: .default,
                                      handler: { (action) in
                                        guard let settingsURL = NSURL(string: UIApplicationOpenSettingsURLString) as URL? else { return }
                                        UIApplication.shared.openURL(settingsURL)
                                        self.hideOverlay()
                                      }
        ))
        alert.addAction(UIAlertAction(title: "Cancel",
                                      style: UIAlertActionStyle.cancel,
                                      handler: { (action) in
                                        self.hideOverlay()
                                      }
        ))
        self.present(alert, animated: true, completion: nil)
      }
    }
  }

  func hideOverlay() {
    DispatchQueue.main.async {
      if let viewWithTag = self.view.viewWithTag(1000) {
        viewWithTag.removeFromSuperview()
      }
    }
  }

  @IBAction func prepareForUnwind(segue: UIStoryboardSegue) {
    // allow app to go idle when entropy generation has completed
    DispatchQueue.main.async {
      UIApplication.shared.isIdleTimerDisabled = false
    }
    hideOverlay()
  }

  @IBAction func copyPK(_ sender: Any) {
    UIPasteboard.general.string = devicePK.text
  }

  func showError(_ title: String, _ msg: String) {
    hideOverlay()
    let alert = UIAlertController(title: title, message: msg, preferredStyle: UIAlertControllerStyle.alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
    self.present(alert, animated: true, completion: nil)
  }

  func clearCache() {
    let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    do {
      let directoryContents = try FileManager.default.contentsOfDirectory(
        at: cacheURL, includingPropertiesForKeys: nil, options: [])

      for file in directoryContents {
        if file.path.range(of: "TE_block") != nil {
          try FileManager.default.removeItem(at: file)
        }
      }
    } catch {
      /* can't clear cache */
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    defaults.set(relayURL.text, forKey: "relay")
    defaults.set(recipientAddress.text, forKey: "recipient")
    self.view.endEditing(true)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    defaults.set(relayURL.text, forKey: "relay")
    defaults.set(recipientAddress.text, forKey: "recipient")
    self.view.endEditing(true)
    return false
  }
}
