//
//  MGMSpruceSSL.m
//  SpruceSSL
//
//  Created by Mr. Gecko on 10/31/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import "MGMSpruceSSL.h"
#import "MGMWebViewMethods.h"
#import "MGMSpruceURL.h"
#import "Safari.h"
#import <objc/objc.h>
#import <objc/objc-class.h>
#import <objc/objc-runtime.h>
#import <Sparkle/Sparkle.h>

@protocol MGMFileManagerProtocol <NSObject>
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes;

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)removeFileAtPath:(NSString *)path handler:(id)handler;

- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)copyPath:(NSString *)source toPath:(NSString *)destination handler:(id)handler;

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)movePath:(NSString *)source toPath:(NSString *)destination handler:(id)handler;
@end

NSString * const MGMSpruceSSLDBChanged = @"MGMSpruceSSLDBChanged";
NSString * const MGMChangeCookies = @"MGMChangeCookies";

NSString * const MGMApplicationSupportPath = @"~/Library/Application Support/MrGeckosMedia/SpruceSSL/";
NSString * const MGMHostWhitelist = @"hostWhitelist.plist";
NSString * const MGMHostBlacklist = @"hostBlacklist.plist";

static MGMSpruceSSL *MGMSpruceSSLShared;

void _objc_flush_caches(Class cls);

void MGMSwizzle(Class class, SEL selector1, SEL selector2) {
#if OBJC_API_VERSION >= 2
	Method method1 = class_getInstanceMethod(class, selector1);
	Method method2 = class_getInstanceMethod(class, selector2);
	
	class_addMethod(class, selector1, class_getMethodImplementation(class, selector1), method_getTypeEncoding(method1));
	class_addMethod(class, selector2, class_getMethodImplementation(class, selector2), method_getTypeEncoding(method2));
	if (method1==NULL || method2==NULL) {
		NSLog(@"Unable to swizzle %@ with %@ in class %@", NSStringFromSelector(selector1), NSStringFromSelector(selector2), NSStringFromClass(class));
		return;
	}
	
	method_exchangeImplementations(class_getInstanceMethod(class, selector1), class_getInstanceMethod(class, selector2));
#else
	Method method1 = NULL, method2 = NULL;
	
	void *iterator = NULL;
	struct objc_method_list *list = class_nextMethodList(class, &iterator);
	while (list!=NULL) {
		for (int i=0; i<list->method_count; i++) {
			if (list->method_list[i].method_name==selector1 && method1==NULL)
				method1 = &list->method_list[i];
			if (list->method_list[i].method_name==selector2 && method2==NULL)
				method2 = &list->method_list[i];
		}
		if (method1!=NULL)
			break;
		list = class_nextMethodList(class, &iterator);
	}
	if (method1==NULL || method2==NULL) {
		NSLog(@"Unable to swizzle %@ with %@ in class %@", NSStringFromSelector(selector1), NSStringFromSelector(selector2), NSStringFromClass(class));
		return;
	}
	
	IMP implementation1 = method1->method_imp;
	IMP implementation2 = method2->method_imp;
	method1->method_imp = implementation2;
	method2->method_imp = implementation1;
#endif
	_objc_flush_caches(class);
}

@implementation MGMSpruceSSL
+ (void)initialize {
	[self sharedController];
}
+ (void)load {
	[self sharedController];
}
+ (MGMSpruceSSL *)sharedController {
	@synchronized(self) {
		if (MGMSpruceSSLShared==nil)
			[[self alloc] init];
	}
	return MGMSpruceSSLShared;
}
+ (id)allocWithZone:(NSZone *)zone {
	@synchronized(self) {
        if (MGMSpruceSSLShared==nil) {
			MGMSpruceSSLShared = [super allocWithZone:zone];
			return MGMSpruceSSLShared;
		}
	}
	return nil;
}

- (id)init {
	if (self = [super init]) {
		NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
		NSArray *supportedIdentifiers = [[[NSBundle bundleForClass:[MGMSpruceSSL class]] infoDictionary] objectForKey:@"MGMSupported"];
		BOOL shouldLoad = NO;
		for (int i=0; i<[supportedIdentifiers count]; i++) {
			if ([[supportedIdentifiers objectAtIndex:i] isEqual:identifier] || ([[supportedIdentifiers objectAtIndex:i] hasSuffix:@"."] && [identifier hasPrefix:[supportedIdentifiers objectAtIndex:i]])) {
				shouldLoad = YES;
				break;
			}
		}
		if (!shouldLoad) {
			[super release];
			return nil;
		}
		
		updater = [SUUpdater alloc];
		if ([updater respondsToSelector:@selector(initForBundle:)]) {
			[updater initForBundle:[NSBundle bundleForClass:[MGMSpruceSSL class]]];
		} else if ([updater respondsToSelector:@selector(setHostBundle:)]) {
			[updater init];
			[updater performSelector:@selector(setHostBundle:) withObject:[NSBundle bundleForClass:[MGMSpruceSSL class]]];
		} else {
			[updater release];
			updater = nil;
		}
		
		NSFileManager<MGMFileManagerProtocol> *manager = [NSFileManager defaultManager];
		if (![manager fileExistsAtPath:[MGMApplicationSupportPath stringByExpandingTildeInPath]]) {
			if ([manager respondsToSelector:@selector(createDirectoryAtPath:attributes:)]) {
				[manager createDirectoryAtPath:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByDeletingLastPathComponent] attributes:nil];
				[manager createDirectoryAtPath:[MGMApplicationSupportPath stringByExpandingTildeInPath] attributes:nil];
			} else {
				[manager createDirectoryAtPath:[MGMApplicationSupportPath stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
			}
		}
		if (![manager fileExistsAtPath:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist]]) {
			whitelist = [[NSMutableArray arrayWithContentsOfFile:[[[NSBundle bundleForClass:[MGMSpruceSSL class]] resourcePath] stringByAppendingPathComponent:MGMHostWhitelist]] retain];
			[whitelist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist] atomically:NO];
		} else {
			whitelist = [[NSMutableArray arrayWithContentsOfFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist]] retain];
		}
		if (![manager fileExistsAtPath:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist]]) {
			blacklist = [[NSMutableArray arrayWithContentsOfFile:[[[NSBundle bundleForClass:[MGMSpruceSSL class]] resourcePath] stringByAppendingPathComponent:MGMHostBlacklist]] retain];
			[blacklist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist] atomically:NO];
		} else {
			blacklist = [[NSMutableArray arrayWithContentsOfFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist]] retain];
		}
		
		MGMSwizzle([NSURLConnection class], @selector(initWithRequest:delegate:startImmediately:), @selector(MGMInitWithRequest:delegate:startImmediately:));
		MGMSwizzle([NSURLConnection class], @selector(initWithRequest:delegate:), @selector(MGMInitWithRequest:delegate:));
		MGMSwizzle([NSURLConnection class], @selector(initWithRequest:delegate:priority:), @selector(MGMInitWithRequest:delegate:priority:));
		MGMSwizzle([NSURLConnection class], @selector(_initWithRequest:delegate:usesCache:maxContentLength:startImmediately:connectionProperties:), @selector(MGMInitWithRequest:delegate:usesCache:maxContentLength:startImmediately:connectionProperties:));
		
		[NSURLProtocol registerClass:[MGMSpruceURL class]];
		
		NSMenu *applicationMenu = [[[NSApp mainMenu] itemAtIndex:0] submenu];
		for (int i=0; i<[applicationMenu numberOfItems]; i++) {
			if ([[applicationMenu itemAtIndex:i] isSeparatorItem]) {
				SpruceSSLMenu = [[[NSMenuItem alloc] initWithTitle:@"SpruceSSL Preferences" action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
				[SpruceSSLMenu setTarget:self];
				[applicationMenu insertItem:SpruceSSLMenu atIndex:i];
				break;
			}
		}
		
		NSNotificationCenter *notifications = [NSNotificationCenter defaultCenter];
		[notifications addObserver:self selector:@selector(willTerminate) name:NSApplicationWillTerminateNotification object:nil];
		[notifications addObserver:self selector:@selector(cookieCheck:) name:WebViewProgressFinishedNotification object:nil];
		
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(dbChanged) name:MGMSpruceSSLDBChanged object:nil];
		
		NSLog(@"SpruceSSL loaded successfully");
	}
	return self;
}
- (id)copyWithZone:(NSZone *)zone {
	return self;
}
- (id)retain {
	return self;
}
- (NSUInteger)retainCount {
	return UINT_MAX;
}
- (void)release {
	
}
- (id)autorelease {
	return self;
}

- (void)willTerminate {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[updater release];
	[blacklist release];
	[whitelist release];
}

- (void)registerDefaults {
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithInt:0] forKey:MGMChangeCookies];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)dbChanged:(NSNotification *)theNotification {
	if ([theNotification object]!=self) {
		[whitelist release];
		whitelist = [[NSMutableArray arrayWithContentsOfFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist]] retain];
		[blacklist release];
		blacklist = [[NSMutableArray arrayWithContentsOfFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist]] retain];
		if (preferencesWindow!=nil) {
			[whitelistTable reloadData];
			[blacklistTable reloadData];
		}
	}
}
- (void)saveDB {
	[whitelist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist] atomically:NO];
	[blacklist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist] atomically:NO];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:MGMSpruceSSLDBChanged object:self];
}

- (IBAction)showPreferences:(id)sender {
	if (preferencesWindow==nil) {
		if (![NSBundle loadNibNamed:@"preferences" owner:self]) {
			NSLog(@"Unable to load preferences for SpruceSSL");
		} else {
			NSBundle *bundle = [NSBundle bundleForClass:[MGMSpruceSSL class]];
			[nameField setStringValue:[NSString stringWithFormat:@"%@ %@", [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey], [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]]];		
			[changeCookiesMatrix selectCellAtRow:[[NSUserDefaults standardUserDefaults] integerForKey:MGMChangeCookies] column:0];
			[wlRemoveButton setEnabled:NO];
			[blRemoveButton setEnabled:NO];
		}
	}
	[preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction)changeCookies:(id)sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[changeCookiesMatrix selectedRow] forKey:MGMChangeCookies];
}
- (IBAction)checkForUpdate:(id)sender {
	[updater checkForUpdates:sender];
}
- (IBAction)donate:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=SA4DEZGVJSNAL"]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)theTableView {
	if (theTableView==whitelistTable)
		return [whitelist count];
	return [blacklist count];
}
- (id)tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)theTableColumn row:(NSInteger)rowIndex {
	if (theTableView==whitelistTable)
		return [whitelist objectAtIndex:rowIndex];
	return [blacklist objectAtIndex:rowIndex];
}
- (void)tableView:(NSTableView *)theTableView setObjectValue:(id)theObject forTableColumn:(NSTableColumn *)theTableColumn row:(NSInteger)rowIndex {
	if (theTableView==whitelistTable) {
		[whitelist replaceObjectAtIndex:rowIndex withObject:theObject];
		[self saveDB];
	} else {
		[blacklist replaceObjectAtIndex:rowIndex withObject:theObject];
		[self saveDB];
	}
}
- (void)tableViewSelectionDidChange:(NSNotification *)theNotification {
	if ([theNotification object]==whitelistTable)
		[wlRemoveButton setEnabled:([whitelistTable selectedRow]>=0)];
	else
		[blRemoveButton setEnabled:([blacklistTable selectedRow]>=0)];
}

- (IBAction)wlAdd:(id)sender {
	[whitelist addObject:@".example.com"];
	[whitelistTable reloadData];
	[whitelistTable editColumn:0 row:[whitelist count]-1 withEvent:nil select:YES];
	[self saveDB];
}
- (IBAction)wlRemove:(id)sender {
	[whitelist removeObjectAtIndex:[whitelistTable selectedRow]];
	[whitelistTable reloadData];
	[self saveDB];
}

- (IBAction)blAdd:(id)sender {
	[blacklist addObject:@".example.com"];
	[blacklistTable reloadData];
	[blacklistTable editColumn:0 row:[blacklist count]-1 withEvent:nil select:YES];
	[self saveDB];
}
- (IBAction)blRemove:(id)sender {
	[blacklist removeObjectAtIndex:[blacklistTable selectedRow]];
	[blacklistTable reloadData];
	[self saveDB];
}


- (void)windowWillClose:(NSNotification *)theNotification {
	preferencesWindow = nil;
}

- (void)cookieCheck:(NSNotification *)theNotification {
	if ([[theNotification object] mainFrameURL]!=nil) {
#if MGMSpruceDebug
		NSLog(@"Cookie check %@", [[theNotification object] mainFrameURL]);
#endif
		MGMSpruceSSL *spruceSSL = [MGMSpruceSSL sharedController];
		NSURL *url = [NSURL URLWithString:[[theNotification object] mainFrameURL]];
		if ([url host]!=nil && [[url scheme] isEqual:@"https"] && (([[NSUserDefaults standardUserDefaults] integerForKey:MGMChangeCookies]==1 && [spruceSSL isSSLForHost:[url host]]) || ([[NSUserDefaults standardUserDefaults] integerForKey:MGMChangeCookies]==2 && ![spruceSSL isHostBlackListed:[url host]]))) {
			NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
			NSArray *cookies = [storage cookiesForURL:url];
			for (unsigned int i=0; i<[cookies count]; i++) {
				if (![[cookies objectAtIndex:i] isSecure]) {
					NSMutableDictionary *cookie = [[[cookies objectAtIndex:i] properties] mutableCopy];
					[cookie setObject:[NSNumber numberWithBool:YES] forKey:NSHTTPCookieSecure];
					[storage setCookie:[NSHTTPCookie cookieWithProperties:cookie]];
					[cookie release];
				}
			}
		}
	}
}

- (NSURLRequest *)requestForRequest:(NSURLRequest *)request {
	if ([[request URL] host]!=nil && [[[request URL] scheme] isEqual:@"http"] && [self isSSLForHost:[[request URL] host]]) {
		NSMutableURLRequest *sslRequest = [[request mutableCopy] autorelease];
		NSString *url = [[sslRequest URL] absoluteString];
		NSRange range = [url rangeOfString:@":"];
		url = [@"sprucessl" stringByAppendingString:[url substringFromIndex:range.location]];
#if MGMSpruceDebug
		NSLog(@"%@", url);
#endif
		[sslRequest setURL:[NSURL URLWithString:url]];
		return sslRequest;
	}
	return request;
}

- (BOOL)doesList:(NSArray *)theList containHost:(NSString *)theHost {
	for (unsigned int i=0; i<[theList count]; i++) {
		NSString *host = [theList objectAtIndex:i];
		if ([host hasPrefix:@"."]) {
			if ([host isEqual:[@"." stringByAppendingString:theHost]]) {
				return YES;
			} else {
				NSMutableArray *domainComponets = [NSMutableArray arrayWithArray:[theHost componentsSeparatedByString:@"."]];
				for (int d=0; d<[domainComponets count]; d++) {
					[domainComponets removeObjectAtIndex:0];
					if ([host isEqual:[@"." stringByAppendingString:[domainComponets componentsJoinedByString:@"."]]]) {
						return YES;
						break;
					}
				}
			}
		} else if ([host isEqual:theHost]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)isHostBlackListed:(NSString *)theHost {
	return [self doesList:blacklist containHost:theHost];
}
- (BOOL)isHostWhiteListed:(NSString *)theHost {
	return [self doesList:whitelist containHost:theHost];
}

- (BOOL)isSSLForHost:(NSString *)theHost {
	if ([self isHostBlackListed:theHost])
		return NO;
	return [self isHostWhiteListed:theHost];
}
@end