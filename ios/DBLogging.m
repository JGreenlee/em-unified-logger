//
//  DBLogging.m
//  referenceSidebarApp
//
//  Created by Kalyanaraman Shankari on 1/9/16.
//
//

#import "DBLogging.h"

// Table name
#define TABLE_LOG @"logTable"

#define KEY_ID @"ID"
#define KEY_TS @"ts"
#define KEY_LEVEL @"level"
#define KEY_MESSAGE @"message"

#define DB_FILE_NAME @"loggerDB"

@interface DBLogging()

@end

@implementation DBLogging

static DBLogging *_database;

+ (DBLogging*)database {
    if (_database == nil) {
        _database = [[DBLogging alloc] init];
    }
    return _database;
}

// TODO: Refactor this into a new database helper class?
- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [self dbPath:DB_FILE_NAME];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath: sqLiteDb]) {
            // Copy existing database over to create a blank DB.
            // Apparently, we cannot create a new file there to work as the database?
            // http://stackoverflow.com/questions/10540728/creating-an-sqlite3-database-file-through-objective-c
            NSError *error = nil;
            NSString *readableDBPath = [[NSBundle mainBundle] pathForResource:DB_FILE_NAME
                                                                       ofType:nil];
            NSLog(@"Copying file from %@ to %@", readableDBPath, sqLiteDb);
            BOOL success = [[NSFileManager defaultManager] copyItemAtPath:readableDBPath
                                                                   toPath:sqLiteDb
                                                                    error:&error];
            if (!success)
            {
                NSCAssert1(0, @"Failed to create writable database file with message '%@'.", [  error localizedDescription]);
                return nil;
            }
        }
        // if we didn't have a file earlier, we just created it.
        // so we are guaranteed to always have a file when we get here
        assert([fileManager fileExistsAtPath: sqLiteDb]);
        int returnCode = sqlite3_open([sqLiteDb UTF8String], &_database);
        if (returnCode != SQLITE_OK) {
            NSLog(@"Failed to open database because of error code %d", returnCode);
            return nil;
        }
    }
    return self;
}

- (NSString*)dbPath:(NSString*)dbName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                         NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    NSString *nosync = [libraryDirectory stringByAppendingPathComponent:@"LocalDatabase"];
    NSString *dbPath = [nosync stringByAppendingPathComponent:dbName];

    NSError *err;
    if ([[NSFileManager defaultManager] fileExistsAtPath: nosync])
    {  
        NSLog(@"no cloud sync at path: %@", nosync);
        return dbPath;
    } else
    {  
        if ([[NSFileManager defaultManager] createDirectoryAtPath: nosync withIntermediateDirectories:NO attributes: nil error:&err])
        {  
            NSURL *nosyncURL = [ NSURL fileURLWithPath: nosync];
            if (![nosyncURL setResourceValue: [NSNumber numberWithBool: YES] 
                                      forKey: NSURLIsExcludedFromBackupKey error: &err]) {  
                NSLog(@"IGNORED: error setting nobackup flag in LocalDatabase directory: %@", err);
            }
            NSLog(@"no cloud sync at path: %@", nosync);
            return dbPath;
        }
        else
        {
                // fallback:
            NSLog(@"WARNING: error adding LocalDatabase directory: %@", err);
            return [libraryDirectory stringByAppendingPathComponent:dbName];
        }
    }
    return dbPath;
}

- (void)dealloc {
    sqlite3_close(_database);
}

/*
 * BEGIN: database logging
 */

-(void)log:(NSString *)message atLevel:(NSString*)level {
    NSLog(@"%@: %@", level, message);
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?)",
                                 TABLE_LOG, KEY_TS, KEY_LEVEL, KEY_MESSAGE];
    
    sqlite3_stmt *compiledStatement;
    NSInteger insertPrepCode = sqlite3_prepare_v2(_database, [insertStatement UTF8String], -1, &compiledStatement, NULL);
    if(insertPrepCode == SQLITE_OK) {
        // The SQLITE_TRANSIENT is used to indicate that the raw data (userMode, tripId, sectionId
        // is not permanent data and the SQLite library should make a copy
        sqlite3_bind_double(compiledStatement, 1, [NSDate date].timeIntervalSince1970);
        sqlite3_bind_text(compiledStatement, 2, [level UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(compiledStatement, 3, [message UTF8String], -1, SQLITE_TRANSIENT);
        NSInteger execCode = sqlite3_step(compiledStatement);
        if (execCode != SQLITE_DONE) {
            @throw [NSException exceptionWithName:@"SQLError"
                        reason:[NSString stringWithFormat:@"Got error code %ld while executing statement %@", (long)execCode, insertStatement]
                        userInfo: nil];
        }
    } else {
        @throw [NSException exceptionWithName:@"SQLError"
                    reason:[NSString stringWithFormat:@"Got error code %ld while compiling statement %@", (long)insertPrepCode, insertStatement]
                    userInfo: nil];
    }
    // Shouldn't this be within the prior if?
    // Shouldn't we execute the compiled statement only if it was generated correctly?
    // This is code copied from
    // http://stackoverflow.com/questions/2184861/how-to-insert-data-into-a-sqlite-database-in-iphone
    // Need to check from the raw sources and see where we get
    // Create a new sqlite3 database like so:
    // http://www.raywenderlich.com/902/sqlite-tutorial-for-ios-creating-and-scripting
    sqlite3_finalize(compiledStatement);
}

-(void)clear {
    NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@", TABLE_LOG];
    [self execDeleteStatement:deleteQuery];
}

-(void)truncateObsolete {
    // We somewhat arbitrarily decree that entries that are over a month old are obsolete
    // This is to avoid unbounded growth of the log table
    double monthAgoTs = [NSDate date].timeIntervalSince1970 - 30 * 24 * 60 * 60; // 30 days * 24 hours * 60 minutes * 60 secs
    [self log:[NSString stringWithFormat:@"truncating obsolete entries before %@", @(monthAgoTs)] atLevel:@"INFO"];
    NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ < %@", TABLE_LOG, KEY_TS, @(monthAgoTs)];
    [self execDeleteStatement:deleteQuery];
}
  
- (void) execDeleteStatement:(NSString*)deleteQuery {
    sqlite3_stmt *compiledStatement;
    NSInteger delPrepCode = sqlite3_prepare_v2(_database, [deleteQuery UTF8String], -1, &compiledStatement, NULL);
    if (delPrepCode == SQLITE_OK) {
        NSInteger execCode = sqlite3_step(compiledStatement);
        if (execCode != SQLITE_DONE) {
            @throw [NSException exceptionWithName:@"SQLError"
                        reason:[NSString stringWithFormat:@"Got error code %ld while executing statement %@", (long)execCode, deleteQuery]
                        userInfo: nil];
        }
    } else {
        @throw [NSException exceptionWithName:@"SQLError"
                    reason:[NSString stringWithFormat:@"Got error code %ld while compiling statement %@", (long)delPrepCode, deleteQuery]
                    userInfo: nil];
    }
    sqlite3_finalize(compiledStatement);
}

-(int)getMaxIndex {
    NSString* selectQuery = [NSString stringWithFormat:@"SELECT MAX(ID) FROM %@", TABLE_LOG];
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [selectQuery UTF8String], -1, &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        if (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            return sqlite3_column_int(compiledStatement, 0);
        }
    }
    return -1;
}

- (NSString*) toNSString:(char*)cString
{
    if (cString == NULL) {
        return @"none";
    } else {
        return [[NSString alloc] initWithUTF8String:cString];
    }
}

- (NSArray*) readSelectResults:(NSString*) selectQuery {
    NSMutableArray* retVal = [[NSMutableArray alloc] init];
    
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [selectQuery UTF8String], -1, &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            NSMutableDictionary* currRow = [[NSMutableDictionary alloc] init];
            int nCols = sqlite3_column_count(compiledStatement);
            if (nCols != 4) {
               NSLog(@"Found %d cols, expected 4", nCols);
            }
            // Remember that while reading results, the index starts from 0
            currRow[KEY_ID] = @((int)sqlite3_column_int(compiledStatement, 0));
            currRow[KEY_TS] = @((double)sqlite3_column_double(compiledStatement, 1));
            currRow[KEY_LEVEL] = [self toNSString:(char*)sqlite3_column_text(compiledStatement, 2)];
            currRow[KEY_MESSAGE] = [self toNSString:(char*)sqlite3_column_text(compiledStatement, 3)];
            [retVal addObject:currRow];
        }
    } else {
        NSLog(@"Error code %ld while compiling query %@", (long)selPrepCode, selectQuery);
    }
    sqlite3_finalize(compiledStatement);
    return retVal;
}

-(NSArray*) getMessagesFromIndex:(int)startIndex forCount:(int)count {
    NSString* selectQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ < %d ORDER BY %@ DESC LIMIT %d",
                             TABLE_LOG, KEY_ID, startIndex, KEY_ID, count];
    return [self readSelectResults:selectQuery];
}


/*
 * END: database logging
 */

@end
