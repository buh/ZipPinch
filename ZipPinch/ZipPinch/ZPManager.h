//
//  ZPManager.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPArchive.h"

typedef void(^ZPManagerDataCompletionBlock)(NSData *data);

@interface ZPManager : NSObject

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSArray *entries;
@property (nonatomic, readonly) NSString *baseCachePath;

- (instancetype)initWithURL:(NSURL *)URL;

/// Enable file cache at path. If path is nil, then path is /Library/Caches/ZipPinch/.
- (void)enableCacheAtPath:(NSString *)path;

- (void)loadContentWithCompletionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;
- (void)loadDataWithFilePath:(NSString *)filePath completionBlock:(ZPManagerDataCompletionBlock)completionBlock;
- (void)loadDataWithURL:(NSURL *)URL completionBlock:(ZPManagerDataCompletionBlock)completionBlock;

- (void)clearCache;
- (void)clearMemoryCache;
+ (void)clearCacheAtDefaultPath;

@end
