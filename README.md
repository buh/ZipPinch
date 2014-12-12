ZipPinch
========

Recovered https://github.com/epatel/pinch-objc

ZipPinch work with zip file remotely. It read zip file contents without downloading itself and unzip files inside only you needed.

Now ZipPinch only works with AFNetworking 1.3. 

Install
-------
1. Copy files from ```ZipPinch/ZipPinch/*.{h,m}``` to your project
2. Pods: ```pod ZipPinch```

Usage
-----
1. Directly with ```ZPArchive```.
```
// URL with zip file: Top 100 Hubble photos.
NSURL *URL = [NSURL URLWithString:@"http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip"];

ZPArchive *archive = [ZPArchive new];

[archive fetchArchiveWithURL:URL completionBlock:^(long long fileLength, NSArray *entries) {
    // Array containts ZPEntry objects.
    ZPEntry *entry = [entries lastObject];
    
    if (entry) {
        [archive fetchFile:entry completionBlock:^(ZPEntry *entry) {
            // Here entry already with unzipped data.
            UIImage *image = [UIImage imageWithData:entry.data];
        }];
    }
}];
```

2. Use ```ZPManager``` with cache (memory, file) and ```NSData``` in output.


TODO
-----
1. AFNetworking 2.0
2. Error handling.
