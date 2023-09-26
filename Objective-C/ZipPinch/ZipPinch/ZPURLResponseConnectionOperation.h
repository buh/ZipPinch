//
//  ZPURLResponseConnectionOperation.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "AFURLConnectionOperation.h"

@interface ZPURLResponseConnectionOperation : AFURLConnectionOperation

@property (nonatomic) long long fileLength;
@property (nonatomic) NSInteger responseStatusCode;

@end
