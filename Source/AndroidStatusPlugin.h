/*
 
 AndroidStatusPlugin
 James Yuzawa - jyuzawa.com
 github.com/yuzawa-san
 
*/

#import <Cocoa/Cocoa.h>
#import <Adium/AIPlugin.h>

@interface AndroidStatusPlugin : NSObject <AIPlugin> {
    NSLock *lock;
    NSString *jabberService;
}

bool get_mobility(PurpleBuddy *b);
@end