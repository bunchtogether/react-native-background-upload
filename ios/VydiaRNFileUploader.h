//
//  VyduaRNFileUploader.h
//  VydiaRNFileUploader
//
//  Created by John Wehr on 7/20/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>

@interface VydiaRNFileUploader : RCTEventEmitter <RCTBridgeModule, NSURLSessionTaskDelegate, RCTInvalidating>

@end


