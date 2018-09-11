//
//  VyduaRNFileUploader.h
//  VydiaRNFileUploader
//
//  Created by John Wehr on 7/20/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>

@interface Uploader : NSObject <NSURLSessionTaskDelegate>

+ (instancetype)sharedUploader;

- (void) getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void) startUpload:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void) cancelUpload: (NSString *)cancelUploadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;

@end


