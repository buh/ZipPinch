//
//  ZPArchive.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPEntry.h"

typedef void(^ZPArchiveArchiveCompletionBlock)(long long fileLength, NSArray *entries);
typedef void(^ZPArchiveFileCompletionBlock)(ZPEntry *entry);

@interface ZPArchive : NSObject

- (void)fetchArchiveWithURL:(NSURL *)URL completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;
- (void)fetchFile:(ZPEntry *)entry completionBlock:(ZPArchiveFileCompletionBlock)completionBlock;

@end
