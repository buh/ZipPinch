//
//  ZPEntry+NSData.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPEntry+NSData.h"

@implementation ZPEntry (NSData)

- (NSString *)zp_string
{
    return [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
}

- (UIImage *)zp_image
{
    return [UIImage imageWithData:self.data scale:[UIScreen mainScreen].scale];
}

- (id)zp_JSON
{
    NSError *error = nil;
    id JSON = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&error];
    
    if (error) {
        NSLog(@"%@", error);
        
        return nil;
    }
    
    return JSON;
}

@end
