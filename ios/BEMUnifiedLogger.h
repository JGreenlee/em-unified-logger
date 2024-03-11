#import <Cordova/CDV.h>

@interface BEMUnifiedLogger: CDVPlugin

- (void) log:(CDVInvokedUrlCommand*)command;
- (void) clear:(CDVInvokedUrlCommand*)command;

@end
