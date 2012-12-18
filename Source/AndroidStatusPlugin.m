/*
 
 AndroidStatusPlugin
 James Yuzawa - jyuzawa.com
 github.com/yuzawa-san
 
 */


#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIListContact.h>
#import <AdiumLibpurple/AIPurpleGTalkAccount.h>
#import <Adium/AIAccount.h>
#import <libpurple/jabber.h>

#import "AndroidStatusPlugin.h"

@implementation AndroidStatusPlugin

- (void)installPlugin
{
	// make a lock so we don't fight with ourselves
    lock = [[NSLock alloc] init];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	// register event handler
    [notificationCenter addObserver:self selector:@selector(listObjectAttributesChanged:) name:ListObject_StatusChanged object:nil];
}

- (void)uninstallPlugin
{
	// remove event handler and clean up
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [lock release];
}


- (NSString *)pluginAuthor
{
    return @"James Yuzawa";
}

- (NSString *)pluginVersion
{
    return @"1.1";
}

- (NSString *)pluginDescription
{
    return @"Marks GTalk contacts who use Android clients as mobile.";
}

- (NSString *)pluginURL
{
    return @"http://www.jyuzawa.com/";
}


// a list object (likely a contact) has changed their status, examine its mobility
- (void)contactStatusUpdateReceived:(AIListObject *)inObject
{
	// do this only for online GTalk buddies
    if ([inObject isKindOfClass:[AIListContact class]] && [inObject online] &&
        [[(AIListContact *)inObject account] isKindOfClass:[AIPurpleGTalkAccount class]]) {
		
		// get PurpleAccount from the AIListObject which is a AIPurpleGTalkAccount (google talk)
        PurpleAccount *account = [(AIPurpleGTalkAccount *)[(AIListContact *)inObject account] purpleAccount];
		// get PurpleBuddy from that PurpleAccount
        PurpleBuddy *buddy = (account ? purple_find_buddy(account, [inObject.UID UTF8String]) : nil);
		// determine mobility of that buddy
        bool mob=get_mobility(buddy);
		// update AIListContact's mobile flag if changed
        if(mob != [inObject isMobile]){
            [(AIListContact *)inObject setIsMobile:mob notify:NotifyLater];
        }
		
    }
}

- (void)listObjectAttributesChanged:(NSNotification *)notification
{
    AIListObject *inObject = [notification object];
    if (inObject && [inObject isKindOfClass:[AIListContact class]]) {
        [lock lock];
        @try {
            [self contactStatusUpdateReceived:inObject];
        } @finally {
            [lock unlock];
            [(AIListContact *)inObject notifyOfChangedPropertiesSilently:YES];
        }
    }
}


// determine a PurpleBuddy's mobility status by examining resource name
bool get_mobility(PurpleBuddy *b)
{
    NSString* resourceStr;
    JabberStream *js;
    JabberBuddy *jb = NULL;
	// get connection to find JabberBuddy
    PurpleConnection *gc = purple_account_get_connection(purple_buddy_get_account(b));
    if(!gc){
        return NO;
    }
    js = gc->proto_data;
    if(js){
		// get the JabberBuddy using JabberStream and PurpleBuddy
        jb = jabber_buddy_find(js, purple_buddy_get_name(b), FALSE);
    }
    
	// return no if not subscribed or pending
    if(!PURPLE_BUDDY_IS_ONLINE(b)) {
        if(jb && (jb->subscription & JABBER_SUB_PENDING ||
                  !(jb->subscription & JABBER_SUB_TO)))
            return NO;
    }
	// examine if the JabberBuddy is found
    if (jb) {
        JabberBuddyResource *jbr = jabber_buddy_find_resource(jb, NULL);
		// check resource if it exists
        if (jbr && jbr->name){
            resourceStr=[NSString stringWithUTF8String:(jbr->name)];
			// do find substring operation
            NSRange rng = [resourceStr rangeOfString:@"android" options:NSCaseInsensitiveSearch];
            return (rng.location != NSNotFound);
        }
    }
    return NO;
}

@end