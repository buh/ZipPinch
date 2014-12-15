//
//  ZPEntry+NSData.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPEntry.h"

@interface ZPEntry (NSData)

- (NSString *)zp_string;
- (UIImage *)zp_image;
- (id)zp_JSON;

@end
