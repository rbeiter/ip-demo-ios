//
//  AppDelegate.m
//  Twilio IP Messaging Demo
//
//  Copyright (c) 2015 Twilio. All rights reserved.
//

#import "AppDelegate.h"
#import "PushManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

    NSDictionary* localNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (localNotification) {
        [self application:application didReceiveRemoteNotification:localNotification];
    }

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         (UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert)];
#pragma GCC diagnostic pop
    }
    
    return YES;
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    [[PushManager sharedManager] updatePushToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    NSLog(@"Failed to get token, error: %@", error);
    [[PushManager sharedManager] updatePushToken:nil];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    if(notificationSettings.types == UIUserNotificationTypeNone) {
        NSLog(@"Failed to get token, error: Notifications are not allowed");
        [[PushManager sharedManager] updatePushToken:nil];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    if(application.applicationState != UIApplicationStateActive) {
        // If your application supports multiple types of push notifications, you may wish to limit which ones you send to the TwilioIPMessagingClient here
        [[PushManager sharedManager] receivedNotification:userInfo];
    }
}

@end
