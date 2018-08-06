//
//  BackgroundTransferAppDelegate.m
//  VydiaRNFileUploader
//
//  Created by John Wehr on 8/5/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import "BackgroundTransferAppDelegate.h"

@implementation BackgroundTransferAppDelegate

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier
  completionHandler:(void (^)())completionHandler
{
    self.sessionCompletionHandler = completionHandler;
}

@end

