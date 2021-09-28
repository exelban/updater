# Updater

A tiny package that adds an update process to your project

## Install
### Swift Package Manager

Add `https://github.com/exelban/updater` in the Swift Package Manager tab in the XCode.

## Usage

First of all, you need to initialize the Updater. You need to pass providers to the init function that will be used to fetch updates:

```swift
let updater = Updater(name: "Stats",
	providers: [
		Updater.Github(user: "exelban", repo: "stats", asset: "Stats.dmg")
	]
)

updater.check() { result, error in
	if error != nil {
		print("error updater.check() \(error!)")
		return
	}

	let local = Updater.Tag(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
	guard let external = result else {
		print("no external release found")
		return
	}

	if local >= external.tag {
		return
	}

	self.updater.download(url, done: { path in
		self.updater.install(path: path)
	})
}
```

## Supporting providers
Originally this package was designed to work only with Github Releases. But now it supports different providers:

- Github Releases
- Custom server (TODO)


## License
[MIT License](https://github.com/exelban/updater/blob/master/LICENSE)