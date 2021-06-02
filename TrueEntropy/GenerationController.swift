// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT
//
// Entropy generation screen

import UIKit
import AVFoundation
extension String: Error {}

class GenerationController: UIViewController, CameraFramesDelegate, UITableViewDataSource, UITableViewDelegate {
  var frames: CameraFrames?
  var ticker = 0
  var blockNumber = 0
  var timer = Timer()
  var defaults = UserDefaults.standard

  var cameraRadius: CGFloat = 0
  var cameraTopY: CGFloat = 0

  @IBOutlet weak var overlay: UIImageView!
  @IBOutlet weak var overlayView: UIView!
  @IBOutlet weak var overlayStatus: UILabel!
  @IBOutlet weak var settingsTable: UITableView!

  let stats = ["TIME ELAPSED",
               "BYTES IN BUFFER",
               "ENTROPY GENERATED",
               "χ² OF LAST BLOCK",
               "REJECTED FRAMES",
               "OVERSATURATED"]

  override func viewDidLoad() {
    super.viewDidLoad()

    // app should stay always active when entropy generation started
    UIApplication.shared.isIdleTimerDisabled = true

    settingsTable.dataSource = self
    settingsTable.delegate = self
    settingsTable.tableFooterView = UIView()

    cameraRadius = (self.view!.layer.bounds.width - 20) / 2
    cameraTopY = (self.view!.layer.bounds.height - 250) / 2 - cameraRadius
    let hasBottomNotch = (UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0) > 0;
    // fix layout for iPhones with bottom notch (no home button)
    if UIDevice().userInterfaceIdiom == .phone && hasBottomNotch {
      cameraTopY -= 16
    }

    addCameraLayer()

    // Don't update stats if there's no camera available
    if (AVCaptureDevice.devices(for: AVMediaType.video).count > 0) {
      timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
    }
  }

  private func addCameraLayer() {
    let cameraFrame = CGRect(x: 10, y: cameraTopY,  width: cameraRadius * 2, height: cameraRadius * 2)

    // TODO: 'devices(for:)' was deprecated in iOS 10.0: Use AVCaptureDeviceDiscoverySession instead.
    if (AVCaptureDevice.devices(for: AVMediaType.video).count > 0) {
      // Show camera layer
      frames = CameraFrames(dlg:self)
      frames!.previewLayer!.frame = cameraFrame
      frames!.previewLayer!.cornerRadius = cameraRadius
      frames!.previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
      self.view!.layer.addSublayer(frames!.previewLayer!)
    } else {
      // Emulate camera layer if camera is not accessible (simulator?)
      let coloredLayer = CALayer()
      coloredLayer.frame = cameraFrame
      coloredLayer.backgroundColor = Constants.mainColor.cgColor
      coloredLayer.opacity = 0.3
      coloredLayer.cornerRadius = cameraRadius
      self.view!.layer.addSublayer(coloredLayer)
    }
    overlayView.superview?.bringSubviewToFront(overlayView)

    // Circular upload progress bar
    let circleLayer = CAShapeLayer()
    circleLayer.path = progressPath(0)
    circleLayer.strokeColor = Constants.mainColor.cgColor
    circleLayer.fillColor = UIColor.clear.cgColor
    circleLayer.lineWidth = 4
    self.view!.layer.addSublayer(circleLayer)

    // Rotating image on center
    let animation = CABasicAnimation(keyPath: "transform.rotation")
    animation.fromValue = 0
    animation.toValue = CGFloat.pi * 2
    animation.duration = Constants.spinnerAnimationDuration
    animation.repeatCount = .infinity
    animation.isRemovedOnCompletion = false
    overlay.layer.add(animation, forKey: "spinAnimation")
  }

  func localized(_ val: Int) -> String {
    return NumberFormatter.localizedString(from: NSNumber(value: val), number: NumberFormatter.Style.decimal)
  }

  @objc func timerAction() {
    ticker += 1

    // Text animation
    let animation: CATransition = CATransition()
    animation.duration = 0.1
    animation.type = CATransitionType.fade
    animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    for i in 0..<stats.count {
      settingsTable.cellForRow(at: IndexPath(row: i, section: 0))?.layer.add(animation, forKey: "changeTextTransition")
    }

    let ext = self.frames?.extractor
    let col = self.frames?.collector

    // Row 0: Time elapsed
    updateValue(row: 0, val: String(format: "%02i:%02i", ticker / 5 / 60, ticker / 5 % 60))

    // Row 1: Bytes in buffer
    updateValue(row: 1, val: localized(ext!.pos))

    // Row 2: Bytes generated
    updateValue(row: 2, val: localized(col!.totalGenerated))

    // Row 3: χ²
    if col!.lastChi > 0 {
      updateValue(row: 3, val: String(format:"%.2f",  col!.lastChi))
    }

    // Highlight if χ² is over limit
    let x2valueLabel = self.settingsTable.cellForRow(at: IndexPath(row: 3, section: 0))?.detailTextLabel
    if defaults.bool(forKey: "x2_limit_enabled") && (col!.lastChi > defaults.double(forKey: "x2_limit")) {
      x2valueLabel?.textColor = Constants.warningColor
    } else {
      x2valueLabel?.textColor = Constants.mainColor
    }

    // Row 4: Number of frames we reject due to too high mean (i.e camera movement)
    updateValue(row: 4, val: localized(col!.rejectedFrames))

    // Row 5: Corrupt pixels
    updateValue(row: 5, val: String(format:"%.2f%%",  col!.corruptPixels))
  }

  func uploadEntropy(entropy: [UInt8], blockNumber: Int) {
    self.blockNumber = blockNumber
    let timestamp = Int64(NSDate().timeIntervalSince1970)

    // Update circular progress bar, if we are not in unlimited generation mode
    if !defaults.bool(forKey: "block_amount_unlimited") {
      DispatchQueue.main.async {
        let percentage = CGFloat(blockNumber) / CGFloat(self.defaults.integer(forKey: "block_amount"))
        let progressLayer = self.view!.layer.sublayers?[(self.view!.layer.sublayers?.count)!-1] as? CAShapeLayer
        progressLayer?.path = self.progressPath(percentage)
      }
    }

    // Upload block to Zax relay, if in Network mode
    if defaults.string(forKey: "delivery") == "network" {
      do {
        let isLastBlock = !defaults.bool(forKey: "block_amount_unlimited") && (blockNumber == defaults.integer(forKey: "block_amount"))
        if isLastBlock {
          updateStatus("FINISHING UPLOAD")
        }
        try GlowLite.shared.sendFile(keyTo: defaults.string(forKey: "recipient")!,
        file: entropy,
        name: "TE_block\(blockNumber)_\(timestamp).bin") {
          (res) -> () in
          if isLastBlock {
            self.closeView()
          }
        }
      } catch {
        print("Network error")
      }

      return
    }

    // Otherwise, stop generation and prepare for airdrop
    updateStatus("WRITING BLOCK \(blockNumber)")
    frames?.session?.stopRunning()

    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    var files = [URL]()

    if defaults.bool(forKey: "upload_csv") {
      let f = NSMutableString(capacity: entropy.count * 50)
      // Use "Bins" column with Excel Histogram function
      f.append("Values,Bins\n")
      for i in 0 ..< entropy.count {
        f.append(String(entropy[i]))
        if i<256 { f.append(",\(i)") }
        f.append("\n")
      }
      let path1 = dir.appendingPathComponent("TE_block\(blockNumber)_\(timestamp).csv")
      do {
        try f.write(to: path1, atomically: false, encoding: String.Encoding.ascii.rawValue)
        files.append(path1)
      }
      catch {/* error handling here */}
    }

    let path2 = dir.appendingPathComponent("TE_block\(blockNumber)_\(timestamp).bin")
    FileManager.default.createFile(atPath: path2.path, contents: Data(entropy), attributes: nil)
    files.append(path2)

    DispatchQueue.main.async {
      // AirDrop the files
      let controller  = UIActivityViewController(activityItems: files, applicationActivities: nil)
      controller.popoverPresentationController?.sourceView = self.view
      let viewRect = self.view.bounds
      let sourceRect = CGRect(x: 0, y: viewRect.height, width: viewRect.width, height: 0)
      controller.popoverPresentationController?.sourceRect = sourceRect
      controller.preferredContentSize = CGSize(width: viewRect.width, height: viewRect.height)
      controller.completionWithItemsHandler = self.doneSharingHandler
      controller.excludedActivityTypes = [.postToTwitter, .saveToCameraRoll ,.postToFacebook, .postToWeibo, .message, .mail, .print, .copyToPasteboard, .assignToContact, .saveToCameraRoll, .addToReadingList, .postToFlickr, .postToVimeo, .postToTencentWeibo]
      self.present(controller, animated: true)
    }
  }

  func doneSharingHandler(activityType: UIActivity.ActivityType?, shared: Bool, items: [Any]?, error: Error?) {
    if !defaults.bool(forKey: "block_amount_unlimited") && (self.blockNumber == defaults.integer(forKey: "block_amount")) {
      self.closeView()
    } else {
      self.updateStatus("GENERATING ENTROPY")
      self.frames?.session?.startRunning()
    }
  }

  func progressPath(_ percentage: CGFloat) -> CGPath {
    return UIBezierPath(arcCenter: CGPoint(x: 10 + self.cameraRadius, y: self.cameraTopY + self.cameraRadius),
                        radius: self.cameraRadius - 2, startAngle: -CGFloat.pi / 2.0,
                        endAngle: -CGFloat.pi / 2.0 + (CGFloat.pi * 2.0 * percentage), clockwise: true).cgPath
  }

  func updateStatus(_ status: String) {
    DispatchQueue.main.async {
      self.overlayStatus.text = status
    }
  }

  func updateValue(row: Int, val: String) {
    if val == "0" { return }
    DispatchQueue.main.async {
      self.settingsTable.cellForRow(at: IndexPath(row: row, section: 0))?.detailTextLabel?.text = val
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = settingsTable.dequeueReusableCell(withIdentifier: "keyValue")!
    cell.detailTextLabel?.text = " "
    cell.textLabel?.text = stats[indexPath.row]
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return stats.count }
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 40 }
  func numberOfSections(in tableView: UITableView) -> Int { return 1 }

  @IBAction func closeClicked(_ sender: Any) {
    frames?.session?.stopRunning()
    self.closeView()
  }

  func closeView() {
    DispatchQueue.main.async {
      self.performSegue(withIdentifier: "backToSettings", sender: self)
      self.dismiss(animated: false, completion: nil)
    }
  }
}
