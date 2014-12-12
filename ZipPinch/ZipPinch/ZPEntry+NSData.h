//
//  ZPEntry+NSData.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

@import UIKit;
#import "ZPEntry.h"

@interface ZPEntry (NSData)

- (NSString *)string;
- (UIImage *)image;
- (id)JSON;

@end
