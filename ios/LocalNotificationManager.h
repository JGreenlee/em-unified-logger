//
//  LocalNotificationManager.h
//  CFC_Tracker
//
//  Created by Kalyanaraman Shankari on 2/2/15.
//  Copyright (c) 2015 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocalNotificationManager : NSObject

+(void)clearNotifications;
+(void)cancelNotification:(NSNumber*) id;
+(void)addNotification:(NSString*) notificationMessage;
+(void)addNotification:(NSString*) notificationMessage showUI:(BOOL)showUI;
+(void)showNotification:(NSString*) notificationMessage;
+(void)showNotificationAfterSecs:(NSString *)notificationMessage withUserInfo:(NSDictionary*)userInfo
                                                                    secsLater:(int)secsLater;
+(void)schedulePluginCompatibleNotification:(NSDictionary*) currNotifyConfig withNewData:(NSDictionary*)newData;
@end
