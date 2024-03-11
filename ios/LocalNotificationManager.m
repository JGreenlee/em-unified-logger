//
//  LocalNotificationManager.m
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 2/2/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import "LocalNotificationManager.h"
#import "ConfigManager.h"
#import "DBLogging.h"
#import <Cordova/CDV.h>
#import <UIKit/UIKit.h>

@implementation LocalNotificationManager

static int notificationCount = 0;

+(void)clearNotifications {
    notificationCount = 0;
    [[DBLogging database] clear];
}

+(void)addNotification:(NSString *)notificationMessage {
    [self addNotification:notificationMessage showUI:false];
}

+(void)addNotification:(NSString *)notificationMessage showUI:(BOOL)showUI {
    NSLog(@"%@", notificationMessage);
    NSString* level = @"DEBUG";
    if (showUI) {
        level = @"INFO";
    }
    [[DBLogging database] log:notificationMessage atLevel:level];

    // TODO: This adds a dependency between the notification manager and the config manager
    // This is not a good thing, but it works for now
    // Filed https://github.com/e-mission/e-mission-data-collection/issues/113 to track longer term issue
    if (showUI && [ConfigManager instance].simulate_user_interaction) {
        [LocalNotificationManager showNotification:notificationMessage];
    }
}

+(void)showNotification:(NSString *)notificationMessage {
    [LocalNotificationManager addNotification:notificationMessage];
    notificationCount++;
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        localNotif.userInfo = @{};
        if (localNotif) {
            localNotif.alertBody = notificationMessage;
            localNotif.applicationIconBadgeNumber = notificationCount;
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
        }
    }

+(void)showNotificationAfterSecs:(NSString *)notificationMessage withUserInfo:(NSDictionary*)userInfo
                                                                    secsLater:(int)secsLater {
    [LocalNotificationManager addNotification:notificationMessage];
    notificationCount++;
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif) {
        localNotif.alertBody = notificationMessage;
        // localNotif.applicationIconBadgeNumber = notificationCount;
        if (userInfo != NULL) {
            localNotif.userInfo = userInfo;
        } else {
            localNotif.userInfo = @{};
        }
        localNotif.fireDate = [NSDate dateWithTimeIntervalSinceNow:secsLater];
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
    }
}

+(void)cancelNotification:(NSNumber*)id
{
    CDVAppDelegate *ad = [[UIApplication sharedApplication] delegate];
    CDVViewController *vc = ad.viewController;
    CDVInvokedUrlCommand* command = [[CDVInvokedUrlCommand new] initWithArguments:@[id] callbackId:@"FROM_NATIVE_CODE" className:@"LocalNotification" methodName:@"cancel"];
    [vc.commandQueue execute:command];
}

+(void)schedulePluginCompatibleNotification:(NSDictionary*) currNotifyConfig withNewData:(NSDictionary*)newData
{
    NSMutableDictionary* modifiedConfig = [NSMutableDictionary dictionaryWithDictionary:currNotifyConfig];
    [self fillWithDefaults:modifiedConfig key:@"data" defaultVal:@{}];

    NSDictionary* defaultTrigger = @{
        @"type": @"calendar"
    };
    NSDictionary* defaultProgressBar = @{
        @"enabled": @false
    };
    [self fillWithDefaults:modifiedConfig key:@"trigger" defaultVal:defaultTrigger];
    [self fillWithDefaults:modifiedConfig key:@"progressBar" defaultVal:defaultProgressBar];

    NSMutableDictionary* modifiedCurrData = [NSMutableDictionary dictionaryWithDictionary:modifiedConfig[@"data"]];
    if (newData != NULL) {
        [self mergeObjects:modifiedCurrData toAutoGen:newData];
        modifiedConfig[@"data"] = modifiedCurrData;
    }
    // Unlike android, the schedule method in the plugin is
    // private and there is no Manager class that we can work
    // with directly.
    // Let's see if we can call the public method
    // although I am not optimistic
    CDVAppDelegate *ad = [[UIApplication sharedApplication] delegate];
    CDVViewController *vc = ad.viewController;
    CDVInvokedUrlCommand* command = [[CDVInvokedUrlCommand new] initWithArguments:@[modifiedConfig] callbackId:@"FROM_NATIVE_CODE" className:@"LocalNotification" methodName:@"schedule"];
    [vc.commandQueue execute:command];
}

+(void)mergeObjects:(NSMutableDictionary*) existing toAutoGen:(NSDictionary*)autogen {
    [existing addEntriesFromDictionary:autogen];
}

+(void) fillWithDefaults:(NSMutableDictionary*)notifyConfig
                     key:(NSString*) field defaultVal:(NSDictionary*)defaultValue
{
    NSObject* currField = notifyConfig[field];
    if (currField == NULL) {
        [[DBLogging database] log:[NSString stringWithFormat:@"Did not find existing field %@, filling in default %@", currField, defaultValue] atLevel:@"DEBUG"];
        notifyConfig[field] = defaultValue;
    } else {
        [[DBLogging database] log:[NSString stringWithFormat:@"Found existing field %@, retaining existing", currField] atLevel:@"DEBUG"];
    }
}

@end
