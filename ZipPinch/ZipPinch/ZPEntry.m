//
//  ZPEntry.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPEntry.h"
#import "ZPArchive.h"

@implementation ZPEntry

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self) {
        _URL = [coder decodeObjectForKey:@"URL"];
        _filePath = [coder decodeObjectForKey:@"filePath"];
        _offset = [coder decodeIntegerForKey:@"offset"];
        _method = [coder decodeIntegerForKey:@"method"];
        _sizeCompressed = [coder decodeIntegerForKey:@"sizeCompressed"];
        _sizeUncompressed = [coder decodeIntegerForKey:@"sizeUncompressed"];
        _crc32 = [coder decodeIntegerForKey:@"crc32"];
        _filenameLength = [coder decodeIntegerForKey:@"filenameLength"];
        _extraFieldLength = [coder decodeIntegerForKey:@"extraFieldLength"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_URL forKey:@"URL"];
    [coder encodeObject:_filePath forKey:@"filePath"];
    [coder encodeInteger:_offset forKey:@"offset"];
    [coder encodeInteger:_method forKey:@"method"];
    [coder encodeInteger:_sizeCompressed forKey:@"sizeCompressed"];
    [coder encodeInteger:_sizeUncompressed forKey:@"sizeUncompressed"];
    [coder encodeInteger:_crc32 forKey:@"crc32"];
    [coder encodeInteger:_filenameLength forKey:@"filenameLength"];
    [coder encodeInteger:_extraFieldLength forKey:@"extraFieldLength"];
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@" %@ size:%li uncompressed:%li",
            _filePath, (long)_sizeCompressed, (long)_sizeUncompressed];
}

@end
