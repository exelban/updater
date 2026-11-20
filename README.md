# Updater

A Swift package for updating signed macOS applications from disk images. Requires macOS 12 Monterey or later.

## Install

Add `https://github.com/exelban/updater` as a Swift Package Manager dependency in Xcode.

## Usage

Give the updater the name of the app inside the DMG and a list of providers in priority order. The first provider to return a release wins. If all providers fail, the completion receives their errors in the same order.

```swift
import Foundation
import Updater

let updater = Updater(name: "Stats", providers: [
    Updater.Github(user: "exelban", repo: "stats", asset: "Stats.dmg")
])

updater.check { release, errors in
    if let errors = errors {
        errors.forEach { print($0.localizedDescription) }
        return
    }

    guard let release = release,
          let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          release.tag.isUpdate(for: Updater.Tag(version)),
          let url = URL(string: release.url) else { return }

    updater.downloadFile(url, progress: { progress in
        print(progress.fractionCompleted)
    }) { result in
        switch result {
        case .success(let image):
            updater.install(image) { error in print(error.localizedDescription) }
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
```

Use `check(force: false)` for automatic checks with a ten-minute cooldown. Manual `check` calls bypass the cooldown. Version tags accept one to three numeric components, an optional leading `v`, and an optional `-beta` or `-betaN` suffix. Stable installations skip betas by default. To opt in, pass `includingBetas: true` to both `isUpdate` and `install`.

Downloads are saved in Downloads. The returned task supports cancellation. Dispatch UI updates to the main queue from completion and progress callbacks.

## Custom server

`Updater.Server(url:asset:)` reads a release in this format:

```json
{"tag":"v2.1.0","assets":[{"name":"Stats.dmg","download_url":"https://example.com/Stats.dmg"}]}
```

Set `includeMacOSVersion: true` to send the host version in the `macOS` query parameter. Place the server before GitHub in the providers array to use GitHub as a fallback.

## Installation

Place the signed app at the root of the disk image. The staged app must match the running app’s designated signing requirement, developer Team ID, and bundle identifier. Its short version must be newer and its declared minimum macOS version must be compatible.

The updater keeps the existing app available until macOS accepts the relaunch. A failed launch restores the previous bundle. On success the original process exits. The updater detaches its own image and removes a successfully installed download it can identify as its own. An image supplied by the caller stays on disk.

Protected destinations use system file-replacement authorization. The host app needs Apple’s [Privileged File Operations entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.security.privileged-file-operations) for this operation. Installation errors are delivered to the supplied callback.

## License

[MIT License](https://github.com/exelban/updater/blob/master/LICENSE)
