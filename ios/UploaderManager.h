//
//  UploaderManager.h
//  UploaderManager
//
//  Created by John Wehr on 7/20/18.
//  Copyright © 2018 John Wehr. All rights reserved.
//


#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>
#import <React/RCTEventEmitter.h>

@interface UploaderManager : RCTEventEmitter <RCTBridgeModule, RCTInvalidating>
- (void)invalidate;
@end

