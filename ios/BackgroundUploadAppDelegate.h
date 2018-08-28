//
//  BackgroundUploadAppDelegate.h
//  VydiaRNFileUploader
//
//  Created by John Wehr on 8/5/18.
//  Copyright © 2018 Marc Shilling. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BackgroundUploadAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) NSMutableDictionary *sessionCompletionHandlers;
@end
