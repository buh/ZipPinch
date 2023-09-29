

`ZipPinch` is an extension for `URLSession` to work with zip files remotely. It reads the contents of a zip file without downloading it itself and decompresses the desired files.

Imagine that you need remote access to several files (different kinds of assets: pictures, fonts, etc.). And these files can be changed and added to. Perhaps these files are grouped, for example, by locale and your app needs assets for a particular locale. In a good way you need a server solution that returns some JSON with a description of available resources. For example, you can use any PaaS, but `ZipPinch` offers a much simpler solution. 

It makes a request to a remote ZIP archive and returns its structure with the size and date of file modification. Free hosting for your zip files is not hard to find. Files in an uncompressed archive will essentially be downloaded as is and no time will be spent on unzipping.

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

# Demo

# TODO
[ ] Add more tests
[ ] Fix Demo for macOS

# Support

You can buy me a coffee [here](https://www.buymeacoffee.com/bukhtin) ☕️

# License

`ZipPinch` is available under the [MIT license](https://github.com/buh/ZipPinch/blob/main/LICENSE)

