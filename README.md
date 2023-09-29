

`ZipPinch` is an extension for `URLSession` to work with zip files remotely. It reads the contents of a zip file without downloading it itself and decompresses the desired files.

Imagine that you need remote access to several files (different kinds of assets: pictures, fonts, etc.). And these files can be changed and added to. Perhaps these files are grouped, for example, by locale and your app needs assets for a particular locale. In a good way you need a server solution that returns some JSON with a description of available resources. For example, you can use any PaaS, but `ZipPinch` offers a much simpler solution. 

It makes a request to a remote ZIP archive and returns its structure with the file size and date of file modification. Free hosting for your zip files is not hard to find. Files in an uncompressed archive will essentially be downloaded as is and no time will be spent on unzipping.

<img src="https://github.com/buh/ZipPinch/assets/284922/316c0139-9abf-4bd9-aa8e-dcd3ac48501f" width="375"/> <img src="https://github.com/buh/ZipPinch/assets/284922/9e06fb2f-1be3-476a-84eb-f58ed1e75c90" width="375"/>

*Screenshots from the Demo app: Hubble*

# Requirements

- Swift 5.6+
- macOS 12+
- iOS 15+
- watchOS 8+

# Installation

1. In Xcode go to `File` ⟩ `Add Packages...`
2. Search for the link below and click `Add Package`
```
https://github.com/buh/ZipPinch.git
```
3. Select to which target you want to add it and select `Add Package`

# Usage

1. First you need to create an instance of `URLSession`. 

```swift
let urlSession = URLSession(configuration: .ephemeral)
```

Then make a request for the contents via a direct `URL` to your ZIP file.

```swift
let entries = try await urlSession.zipEntries(from: url)
```

> [!NOTE]
> You can also add a `URLSessionTaskDelegate` or use a customised `URLRequest`.

2. Then when you have selected the necessary entry to download, you need to make the following request:

```swift
let data = try await urlSession.zipEntryData(entry, from: url)
```

3. Use the data to initiate an image or other types.

Check out the Hubble demo app to view selected images from the archive taken by [The Hubble Space Telescope](https://esahubble.org).

# TODO
- [x] Add custom `URLRequest`
- [x] Add custom decompressor
- [ ] Add more tests
- [ ] Fix Demo for macOS

# ZIP file format specification sources
- [Wikipedia](http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers)
- [PKWARE ZIP File Format Specification](https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.9.TXT)
- [Fossies](https://fossies.org/linux/unzip/proginfo/extrafld.txt)

# Support

You can buy me a coffee [here](https://www.buymeacoffee.com/bukhtin) ☕️

# License

`ZipPinch` is available under the [MIT license](https://github.com/buh/ZipPinch/blob/main/LICENSE)

