//
//  MGMSpruceSSL.h
//  SpruceSSL
//
//  Created by Mr. Gecko on 10/31/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import <Cocoa/Cocoa.h>

@class SUUpdater;

extern NSString * const MGMChangeCookies;

#define MGMSpruceDebug 1

@interface MGMSpruceSSL : NSObject {
	SUUpdater *updater;
	NSMenuItem *SpruceSSLMenu;
	
	NSMutableArray *blacklist;
	NSMutableArray *whitelist;
	
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSTextField *nameField;
	IBOutlet NSMatrix *changeCookiesMatrix;
	IBOutlet NSTableView *whitelistTable;
	IBOutlet NSButton *wlRemoveButton;
	IBOutlet NSTableView *blacklistTable;
	IBOutlet NSButton *blRemoveButton;
}
+ (MGMSpruceSSL *)sharedController;

- (IBAction)changeCookies:(id)sender;
- (IBAction)checkForUpdate:(id)sender;
- (IBAction)donate:(id)sender;

- (IBAction)wlAdd:(id)sender;
- (IBAction)wlRemove:(id)sender;

- (IBAction)blAdd:(id)sender;
- (IBAction)blRemove:(id)sender;

- (NSURLRequest *)requestForRequest:(NSURLRequest *)request;

- (BOOL)doesList:(NSArray *)theList containHost:(NSString *)theHost;

- (BOOL)isHostBlackListed:(NSString *)theHost;
- (BOOL)isHostWhiteListed:(NSString *)theHost;

- (BOOL)isSSLForHost:(NSString *)theHost;
@end