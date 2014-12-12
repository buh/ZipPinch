//
//  ZPURLResponseConnectionOperation.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPURLResponseConnectionOperation.h"

@implementation ZPURLResponseConnectionOperation

- (void)connection:(NSURLConnection *)__unused connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    [super connection:connection didReceiveResponse:response];
    
    _fileLength = response.expectedContentLength;
    _responseStatusCode = response.statusCode;
    
    [self cancel];
}

@end
