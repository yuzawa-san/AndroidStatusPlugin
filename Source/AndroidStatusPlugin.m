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
	lock = [[NSLock alloc] init];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(listObjectAttributesChanged:) name:ListObject_StatusChanged object:nil];
}

- (void)uninstallPlugin
{
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


- (void)contactStatusUpdateReceived:(AIListObject *)inObject
{
	if ([inObject isKindOfClass:[AIListContact class]] && [inObject online] &&
		[[(AIListContact *)inObject account] isKindOfClass:[AIPurpleGTalkAccount class]]) {
		
		PurpleAccount *account = [(AIPurpleGTalkAccount *)[(AIListContact *)inObject account] purpleAccount];
		PurpleBuddy *buddy = (account ? purple_find_buddy(account, [inObject.UID UTF8String]) : nil);
		bool mob=get_mobility(buddy);
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

- (void)accountConnected:(NSNotification *)notification
{
    AIAccount *account = [notification object];
    for (AIListObject *contact in [account contacts]) {
        [lock lock];
        @try {
			[self contactStatusUpdateReceived:contact];
        } @finally {
            [lock unlock];
        }
    }
}

bool get_mobility(PurpleBuddy *b)
{
	NSString* resourceStr;
	JabberStream *js;
	JabberBuddy *jb = NULL;
	PurpleConnection *gc = purple_account_get_connection(purple_buddy_get_account(b));
	if(!gc){
		return NO;
	}
	js = gc->proto_data;
	if(js){
		jb = jabber_buddy_find(js, purple_buddy_get_name(b), FALSE);
	}
	
	if(!PURPLE_BUDDY_IS_ONLINE(b)) {
		if(jb && (jb->subscription & JABBER_SUB_PENDING ||
				  !(jb->subscription & JABBER_SUB_TO)))
			return NO;
	}
	if (jb) {
		JabberBuddyResource *jbr = jabber_buddy_find_resource(jb, NULL);
		if (jbr && jbr->name){
			resourceStr=[NSString stringWithUTF8String:(jbr->name)];
			NSRange rng = [resourceStr rangeOfString:@"android" options:NSCaseInsensitiveSearch];
			return (rng.location != NSNotFound);
		}
	}
	return NO;
}

@end