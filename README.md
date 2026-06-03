# jionews-shortssdk-cocoapod

[![CI Status](https://img.shields.io/travis/Saif/jionews-shortssdk-cocoapod.svg?style=flat)](https://travis-ci.org/Saif/jionews-shortssdk-cocoapod)
[![Version](https://img.shields.io/cocoapods/v/jionews-shortssdk-cocoapod.svg?style=flat)](https://cocoapods.org/pods/jionews-shortssdk-cocoapod)
[![License](https://img.shields.io/cocoapods/l/jionews-shortssdk-cocoapod.svg?style=flat)](https://cocoapods.org/pods/jionews-shortssdk-cocoapod)
[![Platform](https://img.shields.io/cocoapods/p/jionews-shortssdk-cocoapod.svg?style=flat)](https://cocoapods.org/pods/jionews-shortssdk-cocoapod)

JioNews Shorts SDK exposes a vertical, full-screen shorts feed backed by a
**native AVPlayer** (the `getSTBShorts` GraphQL feed). The public surface is a
UIKit `ShortsView`; the SwiftUI feed is hosted internally.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- iOS 17.0+
- Swift 5.9+

## Installation

jionews-shortssdk-cocoapod is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'jionews-shortssdk-cocoapod'
```

## Usage

```swift
import jionews_shortssdk_cocoapod

class ViewController: UIViewController {
    @IBOutlet weak var shortsView: ShortsView!

    override func viewDidLoad() {
        super.viewDidLoad()
        shortsView.configure(
            with: "<HID>",
            token: "<AUTHORIZATION_JWT>"   // sent as the Authorization header to the GraphQL endpoint
        )
        shortsView.delegate = self
    }
}

extension ViewController: ShortsViewDelegate {
    func didTapOnShareButton(_ brief: ShortsVideoBrief) {
        print("Share tapped: \(brief.title ?? "")")
    }
}
```

Playback can be driven externally via `playVideo(isMute:)`, `pauseVideo()`,
`stopVideo()`, `muteVideo()`, `unmuteVideo()`, and `setPlaybackDisable(_:)`.
Call `cleanup()` when tearing the view down.

## Author

Saif, saif.mukadam@ril.com

## License

jionews-shortssdk-cocoapod is available under the MIT license. See the LICENSE file for more info.
