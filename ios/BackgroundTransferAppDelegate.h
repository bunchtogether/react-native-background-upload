//
//  BackgroundTransferAppDelegate.h
//  VydiaRNFileUploader
//
//  Created by John Wehr on 8/3/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BackgroundTransferAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (copy) void (^sessionCompletionHandler)();
@end
