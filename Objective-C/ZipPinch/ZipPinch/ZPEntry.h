//
//  ZPEntry.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ZPArchive;

@interface ZPEntry : NSObject <NSCoding>

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic) NSInteger offset;
@property (nonatomic) NSInteger method;
@property (nonatomic) NSInteger sizeCompressed;
@property (nonatomic) NSInteger sizeUncompressed;
@property (nonatomic) NSUInteger crc32;
@property (nonatomic) NSInteger filenameLength;
@property (nonatomic) NSInteger extraFieldLength;

@property (nonatomic, strong) NSData *data;

@end
