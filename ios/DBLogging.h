//
//  OngoingTripsDatabase.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 9/18/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface DBLogging : NSObject {
    sqlite3 *_database;
}

+(DBLogging*) database;

-(void)log:(NSString*) message atLevel:(NSString*)level;
-(void)clear;
-(void)truncateObsolete;
-(int)getMaxIndex;
-(NSArray*) getMessagesFromIndex:(int)startIndex forCount:(int)count;

@end
