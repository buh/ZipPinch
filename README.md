ZipPinch
========

Recovered [pinch-objc](https://github.com/epatel/pinch-objc).

ZipPinch — work with zip file remotely. It read zip file contents without downloading itself and unzip files that you needed.

NOTE: ZipPinch works with AFNetworking 1.3+. 

Installation
-------
1. Pods: `pod ZipPinch`.
2. Copy files from `ZipPinch/ZipPinch/*.{h,m}` to your project.

Usage
-----
#### 1. Using `ZPArchive`.
```objective-c
// URL with zip file: Top 100 Hubble photos.
NSURL *URL = [NSURL URLWithString:@"http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip"];

// Create zip archive instance.
ZPArchive *archive = [ZPArchive new];

// Fetch zip contents with URL.
[archive fetchArchiveWithURL:URL completionBlock:^(long long fileLength, NSArray *entries, NSError *error) {
    // Array containts ZPEntry objects.
    // If entries not empty, get first item and unzip file.
    ZPEntry *entry = [entries firstObject];
    
    if (entry) {
        // Unzip only one file.
        [archive fetchFile:entry completionBlock:^(ZPEntry *entry, NSError *error) {
            // Now entry with data if error not occurs.
            // For example, create Image from entry data.
            UIImage *image = [UIImage imageWithData:entry.data];
        }];
    }
}];
```

#### 2. Using `ZPManager` with file cache and `NSData` in output.
```objective-c
// URL with zip file: Top 100 Hubble photos.
NSURL *URL = [NSURL URLWithString:@"http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip"];

// Create zip manager with URL.
ZPManager *zipManager = [[ZPManager alloc] initWithURL:URL];

// Enable file cache at default path: /Library/Caches/ZipPinch/.
[zipManager enableCacheAtPath:nil];

// Fetch zip contents with URL.
[zipManager loadContentWithCompletionBlock:^(long long fileLength, NSArray *entries, NSError *error) {
    // Array containts ZPEntry objects.
    // If entries not empty, get first item and unzip file.
    ZPEntry *entry = [entries firstObject];
    
    // Load data with entry.
    [zipManager loadDataWithFilePath:entry.filePath completionBlock:^(NSData *data, NSError *error) {
        // For example, create Image from entry data.
        UIImage *image = [UIImage imageWithData:data];
    }];
}];

// After loading zip contents we can use zipManager.entries property to unzip others files.

// If we know zip internal file structure, we can use URL to load data.
NSURL *imageURL = [URL URLByAppendingPathComponent:@"top100/heic1307.jpg"];

// Unzip image data with imageURL.
[zipManager loadDataWithURL:imageURL completionBlock:^(NSData *data, NSError *error) {
    UIImage *image = [UIImage imageWithData:data];
}];
```
#### 3. Try Demo: `pod try ZipPinch`

TODO
-----
1. AFNetworking 2.0
