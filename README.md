<p align="center">
    <a href="https://itunes.apple.com/us/app/trueentropy/id1299321174">
        <img src="https://i.imgur.com/FjhSNLm.png">
    </a>
</p>

<p align="center">
    <img src="https://img.shields.io/badge/Swift-4.0-blue.svg" />
    <a href="https://itunes.apple.com/us/app/trueentropy/id1299321174">
        <img src="https://img.shields.io/itunes/v/1299321174.svg" alt="Download on the App Store" />
    </a>
    <a href="https://opensource.org/licenses/MIT">
      <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License" />
    </a>
    <a href="https://twitter.com/intent/tweet?text=How%20to%20get%20true%20randomness%20from%20your%20Apple%20device%20with%20particle%20physics%20and%20thermal%20entropy&url=https://medium.com/vault12&via=_vault12_&hashtags=crypto,ios,entropy">
      <img src="https://img.shields.io/twitter/url/http/shields.io.svg?style=social" alt="Tweet" />
    </a>
</p>

Use your phone's camera as a high volume thermal entropy generator - creates genuine random numbers at a rate of over 18 Mb/min.

[<img src="https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg">](https://itunes.apple.com/us/app/trueentropy/id1299321174)

## How it works

<img src="https://i.imgur.com/6860cMn.gif" align="right">

**TrueEntropy** uses your phone's camera to generate true random numbers derived from thermal noise. The camera in your smartphone is so advanced that it can detect even the smallest variations produced by fundamental particle physics. We capture thermal variations in every pixel of your phone's camera to create a powerful, high volume entropy random number generator. No need to move your phone! Leave your phone stationary, and TrueEntropy will pick up a sufficient quantity of thermal variations to generate random numbers at a rate of 18Mb per minute.

* Generate binary files for local use via AirDrop
* Send entropy to a destination machine via cryptographic relays
* Continuous generation mode to constantly reseed target machines

Read [full research notes](https://medium.com/vault12/how-to-get-true-randomness-from-your-apple-device-with-particle-physics-and-thermal-entropy-a9d47ca80c9b) about *TrueEntropy*.

## Features

* Delivering entropy via AirDrop or via network ([Zax relay](https://github.com/vault12/zax))
* Works on iPhone and iPad
* Configurable block size and amount
* Option to decline blocks with low χ²
* Option to generate CSV file for manual testing

## Requirements
iOS 9.3 and Swift 4.0 are required.

## Installation

App depencies have to be install using [CocoaPods](http://cocoapods.org), which is a dependency manager for Cocoa projects. To install it, run:

```bash
$ gem install cocoapods
```

Then, run the following command:

```bash
$ pod install
```

Then open `TrueEntropy.xcworkspace` file.

## Configuration

You can edit particular predefined constants (like *camera resolution*, *range of acceptable sample mean* etc) in [Constants.swift](TrueEntropy/Constants.swift).

## Contributing
We encourage you to contribute to TrueEntropy using [pull requests](https://github.com/vault12/TrueEntropy/pulls).

## Slack Community
We've set up a public slack community [Vault12 Dwellers](https://vault12dwellers.slack.com/). Request an invite by clicking [here](https://slack.vault12.com/).

## License
TrueEntropy is released under the [MIT License](http://opensource.org/licenses/MIT).

## Legal Reminder
Exporting/importing and/or use of strong cryptography software, providing cryptography hooks, or even just communicating technical details about cryptography software is illegal in some parts of the world. If you import this software to your country, re-distribute it from there or even just email technical suggestions or provide source patches to the authors or other people you are strongly advised to pay close attention to any laws or regulations which apply to you. The authors of this software are not liable for any violations you make - it is your responsibility to be aware of and comply with any laws or regulations which apply to you.
