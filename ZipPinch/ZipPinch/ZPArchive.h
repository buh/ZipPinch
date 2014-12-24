//
//  ZPArchive.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPEntry.h"

extern NSString *const ZPEntryErrorDomain;

typedef NS_ENUM(NSUInteger, ZPEntryErrorCode) {
    ZPEntryErrorCodeUnknown,
    ZPEntryErrorCodeResponseEmpty = 100,
    ZPEntryErrorCodeContentsEmpty = 101,
};

typedef void(^ZPArchiveArchiveCompletionBlock)(long long fileLength, NSArray *entries, NSError *error);
typedef void(^ZPArchiveFileCompletionBlock)(ZPEntry *entry, NSError *error);

@interface ZPArchive : NSObject

- (void)fetchArchiveWithURL:(NSURL *)URL completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;
- (void)fetchFile:(ZPEntry *)entry completionBlock:(ZPArchiveFileCompletionBlock)completionBlock;

@end
