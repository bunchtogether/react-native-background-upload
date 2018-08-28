//
//  BackgroundUploadAppDelegate.m
//  VydiaRNFileUploader
//
//  Created by John Wehr on 8/5/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import "BackgroundUploadAppDelegate.h"

@implementation BackgroundUploadAppDelegate

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    [self.sessionCompletionHandlers setObject:completionHandler forKey:identifier];
}

@end

