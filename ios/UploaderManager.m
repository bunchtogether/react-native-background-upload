//
//  UploaderManager.h
//  UploaderManager
//
//  Created by John Wehr on 7/20/18.
//  Copyright © 2018 John Wehr. All rights reserved.
//

#import "UploaderManager.h"
#import <React/RCTBridge.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>
#import <React/RCTEventEmitter.h>
#import "Uploader.h"

@interface UploaderManager ()
@end

@implementation UploaderManager

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
             @"RNFileUploader-initialize",
             @"RNFileUploader-progress",
             @"RNFileUploader-error",
             @"RNFileUploader-cancelled",
             @"RNFileUploader-completed"
            ];
}

-(id) init {
    self = [super init];
    if (self) {
        [Uploader sharedUploader];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleEventNotification:)
                                                     name:@"sendEventWithName"
                                                   object:nil];
    }
    return self;
}

- (void)invalidate {
    [[Uploader sharedUploader] invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleEventNotification:(NSNotification *)notification
{
    [self sendEventWithName:notification.object[@"eventName"] body:notification.object[@"body"]];
}

RCT_EXPORT_METHOD(getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[Uploader sharedUploader] getFileInfo:path resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(startUpload:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[Uploader sharedUploader] startUpload:options resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(cancelUpload: (NSString *)cancelUploadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[Uploader sharedUploader] cancelUpload:cancelUploadId resolve:resolve reject:reject];
}

@end
