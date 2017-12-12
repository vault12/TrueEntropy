// Copyright (c) 2017 Vault12, Inc.
// MIT License https://opensource.org/licenses/MIT
//
// Advanced settings screen

import UIKit

class AdvancedController: UIViewController, UITextFieldDelegate {
  @IBOutlet weak var blockSizeLabel: UILabel!
  @IBOutlet weak var blockSizeStepper: UIStepper!

  @IBOutlet weak var blockAmountLabel: UILabel!
  @IBOutlet weak var blockAmountStepper: UIStepper!
  @IBOutlet weak var infiniteBlocks: UISwitch!

  @IBOutlet weak var chiSquareLimit: UITextField!
  @IBOutlet weak var X2Limit: UISwitch!
  @IBOutlet weak var chiSquareBorder: UIView!

  var defaults = UserDefaults.standard

  override func viewDidLoad() {
    blockSizeStepper.value = defaults.double(forKey: "block_size")
    changeBlockSize(true)
    blockAmountStepper.value = defaults.double(forKey: "block_amount")
    changeBlockAmount(true)
    infiniteBlocks.isOn = defaults.bool(forKey: "block_amount_unlimited")
    switchInfiniteBlocks(true)
    X2Limit.isOn = defaults.bool(forKey: "x2_limit_enabled")
    switchX2Limit(true)

    chiSquareLimit.text = defaults.string(forKey: "x2_limit")
    chiSquareLimit?.delegate = self

    super.viewDidLoad()
  }

  @IBAction func changeBlockSize(_ sender: Any) {
    defaults.set(blockSizeStepper.value, forKey: "block_size")
    blockSizeLabel.text = Constants.blockSizeLabels[(Int(blockSizeStepper.value))]
  }

  @IBAction func changeBlockAmount(_ sender: Any) {
    defaults.set(blockAmountStepper.value, forKey: "block_amount")
    blockAmountLabel.text = "\(Int(blockAmountStepper.value)) block"
    if (blockAmountStepper.value > 1) {
      blockAmountLabel.text?.append("s")
    }
  }

  @IBAction func switchInfiniteBlocks(_ sender: Any) {
    blockAmountStepper.isHidden = infiniteBlocks.isOn
    defaults.set(infiniteBlocks.isOn, forKey: "block_amount_unlimited")
    if (infiniteBlocks.isOn) {
      blockAmountLabel.text = "Infinite blocks"
    } else {
      changeBlockAmount(true)
    }
  }

  @IBAction func switchX2Limit(_ sender: Any) {
    chiSquareLimit.isHidden = !X2Limit.isOn
    chiSquareBorder.isHidden = !X2Limit.isOn
    defaults.set(X2Limit.isOn, forKey: "x2_limit_enabled")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    self.view.endEditing(true)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    self.view.endEditing(true)
    return false
  }

  @IBAction func closePopover(_ sender: Any) {
    defaults.set(Int((chiSquareLimit.text)!), forKey: "x2_limit")
    self.dismiss(animated: true, completion: nil)
  }
}
