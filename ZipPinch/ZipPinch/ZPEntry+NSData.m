//
//  ZPEntry+NSData.m
//  Pods
//
//  Created by Alexey Bukhtin on 17.11.14.
//
//

#import "ZPEntry+NSData.h"

@implementation ZPEntry (NSData)

- (NSString *)string
{
    return [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
}

- (UIImage *)image
{
    return [UIImage imageWithData:self.data scale:[UIScreen mainScreen].scale];
}

- (id)JSON
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
