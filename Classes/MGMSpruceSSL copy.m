//
//  MGMSpruceSSL.m
//  SpruceSSL
//
//  Created by Mr. Gecko on 10/31/10.
//  Copyright 2010 Mr. Gecko's Media. All rights reserved.
//

#import "MGMSpruceSSL.h"
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

NSString * const MGMChangeCookies = @"MGMChangeCookies";

NSString * const MGMApplicationSupportPath = @"~/Library/Application Support/MrGeckosMedia/SpruceSSL/";
NSString * const MGMHostWhitelist = @"hostWhitelist.plist";
NSString * const MGMHostBlacklist = @"hostBlacklist.plist";

static MGMSpruceSSL *MGMSpruceSSLShared;

static IMP MGMResourceWillLoadOriginal;
static IMP MGMLoadFinishedOriginal;

id MGMResourceWillLoadOverride(id self, SEL _cmd, WebView *sender, id identifier, NSURLRequest *request, NSURLResponse *redirectResponse, WebDataSource *dataSource) {
	MGMSpruceSSL *spruceSSL = [MGMSpruceSSL sharedInstance];
	if ([[request URL] host]!=nil && ![[[[[sender mainFrame] dataSource] request] URL] isEqualTo:[request URL]] && [[[request URL] scheme] isEqual:@"http"] && [spruceSSL isSSLForHost:[[request URL] host]]) {
		NSMutableURLRequest *sslRequest = [[request mutableCopy] autorelease];
		NSMutableString *url = [[[[request URL] absoluteString] mutableCopy] autorelease];
		[url insertString:@"s" atIndex:4];
		[sslRequest setURL:[NSURL URLWithString:url]];
		return MGMResourceWillLoadOriginal(self, _cmd, sender, identifier, sslRequest, redirectResponse, dataSource);
	}
	return MGMResourceWillLoadOriginal(self, _cmd, sender, identifier, request, redirectResponse, dataSource);
}
void MGMLoadFinishedOverride(id self, SEL _cmd, WebView *sender) {
	MGMSpruceSSL *spruceSSL = [MGMSpruceSSL sharedInstance];
	NSURL *url = [NSURL URLWithString:[sender mainFrameURL]];
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
	MGMLoadFinishedOriginal(self, _cmd, sender);
}

IMP MGMReplaceImplementation(Class class, SEL selector, IMP implementation) {
	Method method = class_getInstanceMethod(class, selector);
	//if (method_setImplementation!=NULL)
	NSLog(@"Replacing Method");
	return method_setImplementation(method, implementation);
	
	IMP originalImplementation = method_getImplementation(method);
	class_addMethod(class, selector, implementation, NULL);
	return originalImplementation;
}

void MGMSwizzle(Class class1, SEL selector1, Class class2, SEL selector2) {
	NSLog(@"Test Swizzle");
	Method method1 = class_getInstanceMethod(class1, selector1);
	Method method2 = class_getInstanceMethod(class2, selector2);
	IMP implementation1 = method_getImplementation(method1);
	IMP implementation2 = method_getImplementation(method2);
	method_setImplementation(method1, implementation2);
	method_setImplementation(method2, implementation1);
/*#if OBJC_API_VERSION >= 2
	NSLog(@"Swizzling");
	Method method1 = class_getInstanceMethod(class1, selector1);
	if (method1==NULL)
		return;
	
	Method method2 = class_getInstanceMethod(class2, selector2);
	if (method2==NULL)
		return;
	
	class_addMethod(class2, selector1, class_getMethodImplementation(class1, selector1), method_getTypeEncoding(method1));
	class_addMethod(class1, selector2, class_getMethodImplementation(class2, selector2), method_getTypeEncoding(method2));
	
	method_exchangeImplementations(class_getInstanceMethod(class2, selector1), class_getInstanceMethod(class1, selector2));
#else
	NSLog(@"Swizzling Old");
	Method method1 = NULL, method2 = NULL;
	
	void *iterator = NULL;
	struct objc_method_list *list = class_nextMethodList(class1, &iterator);
	while (list!=NULL) {
		for (int i=0; i<list->method_count; i++) {
			if (list->method_list[i].method_name==selector1) {
				method1 = &list->method_list[i];
				break;
			}
		}
		if (method1!=NULL)
			break;
		list = class_nextMethodList(class1, &iterator);
	}
	if (method1==NULL)
		return;
	
	list = class_nextMethodList(class2, &iterator);
	while (list!=NULL) {
		for (int i=0; i<list->method_count; i++) {
			if (list->method_list[i].method_name==selector2) {
				method2 = &list->method_list[i];
				break;
			}
		}
		if (method2!=NULL)
			break;
		list = class_nextMethodList(class2, &iterator);
	}
	if (method2==NULL)
		return;
	
	IMP implementation1 = method1->method_imp;
	IMP implementation2 = method2->method_imp;
	method1->method_imp = implementation2;
	method2->method_imp = implementation1;
#endif*/
}

@implementation MGMSpruceSSL
+ (void)load {
	[[self sharedInstance] load];
}
+ (MGMSpruceSSL *)sharedInstance {
	if (MGMSpruceSSLShared==nil)
		MGMSpruceSSLShared = [[self alloc] init];
	return MGMSpruceSSLShared;
}
- (id)init {
	if (self = [super init]) {
		updater = [[SUUpdater alloc] initForBundle:[NSBundle bundleForClass:[MGMSpruceSSL class]]];
		
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
		
		NSNotificationCenter *notifications = [NSNotificationCenter defaultCenter];
		[notifications addObserver:self selector:@selector(willTerminate) name:NSApplicationWillTerminateNotification object:nil];
	}
	return self;
}
- (void)load {
	NSLog(@"Hello from SpruceSSL");
	//MGMResourceWillLoadOriginal = MGMReplaceImplementation([LoadProgressMonitor class], @selector(webView:resource:willSendRequest:redirectResponse:fromDataSource:), (IMP)MGMResourceWillLoadOverride);
	//MGMLoadFinishedOriginal = MGMReplaceImplementation([BrowserWindowController class], @selector(webViewProgressHasFinished:), (IMP)MGMLoadFinishedOverride);
	
	MGMSwizzle([LoadProgressMonitor class], @selector(webView:resource:willSendRequest:redirectResponse:fromDataSource:), [self class], @selector(webView:resource:willSendRequest:redirectResponse:fromDataSource:));
	MGMSwizzle([BrowserWindowController class], @selector(webViewProgressHasFinished:), [self class], @selector(webViewProgressHasFinished:));
	
	//method_exchangeImplementations(class_getInstanceMethod([LoadProgressMonitor class], @selector(webView:resource:willSendRequest:redirectResponse:fromDataSource:)), class_getInstanceMethod([self class], @selector(webView:resource:willSendRequest:redirectResponse:fromDataSource:)));
	//method_exchangeImplementations(class_getInstanceMethod([BrowserWindowController class], @selector(webViewProgressHasFinished:)), class_getInstanceMethod([self class], @selector(webViewProgressHasFinished:)));
	
	NSMenu *applicationMenu = [[[NSApp mainMenu] itemAtIndex:0] submenu];
	for (int i=0; i<[applicationMenu numberOfItems]; i++) {
		if ([[applicationMenu itemAtIndex:i] isSeparatorItem]) {
			SpruceSSLMenu = [[[NSMenuItem alloc] initWithTitle:@"SpruceSSL Preferences" action:@selector(showPreferences:) keyEquivalent:@""] autorelease];
			[SpruceSSLMenu setTarget:self];
			[applicationMenu insertItem:SpruceSSLMenu atIndex:i];
			break;
		}
	}
}
- (void)willTerminate {
	[updater release];
	[blacklist release];
	[whitelist release];
}

- (void)registerDefaults {
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithInt:0] forKey:MGMChangeCookies];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
	NSLog(@"Hello from bla");
	MGMSpruceSSL *spruceSSL = [MGMSpruceSSL sharedInstance];
	if ([[request URL] host]!=nil && ![[[[[sender mainFrame] dataSource] request] URL] isEqualTo:[request URL]] && [[[request URL] scheme] isEqual:@"http"] && [spruceSSL isSSLForHost:[[request URL] host]]) {
		NSMutableURLRequest *sslRequest = [[request mutableCopy] autorelease];
		NSMutableString *url = [[[[request URL] absoluteString] mutableCopy] autorelease];
		[url insertString:@"s" atIndex:4];
		[sslRequest setURL:[NSURL URLWithString:url]];
		return [spruceSSL webView:sender resource:identifier willSendRequest:sslRequest redirectResponse:redirectResponse fromDataSource:dataSource];
	}
	return [spruceSSL webView:sender resource:identifier willSendRequest:request redirectResponse:redirectResponse fromDataSource:dataSource];
}
- (void)webViewProgressHasFinished:(WebView *)sender {
	MGMSpruceSSL *spruceSSL = [MGMSpruceSSL sharedInstance];
	NSURL *url = [NSURL URLWithString:[sender mainFrameURL]];
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
	[spruceSSL webViewProgressHasFinished:sender];
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
		[whitelist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist] atomically:NO];
	} else {
		[blacklist replaceObjectAtIndex:rowIndex withObject:theObject];
		[blacklist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist] atomically:NO];
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
	[whitelist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist] atomically:NO];
}
- (IBAction)wlRemove:(id)sender {
	[whitelist removeObjectAtIndex:[whitelistTable selectedRow]];
	[whitelistTable reloadData];
	[whitelist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostWhitelist] atomically:NO];
}

- (IBAction)blAdd:(id)sender {
	[blacklist addObject:@".example.com"];
	[blacklistTable reloadData];
	[blacklistTable editColumn:0 row:[blacklist count]-1 withEvent:nil select:YES];
	[blacklist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist] atomically:NO];
}
- (IBAction)blRemove:(id)sender {
	[blacklist removeObjectAtIndex:[blacklistTable selectedRow]];
	[blacklistTable reloadData];
	[blacklist writeToFile:[[MGMApplicationSupportPath stringByExpandingTildeInPath] stringByAppendingPathComponent:MGMHostBlacklist] atomically:NO];
}


- (void)windowWillClose:(NSNotification *)theNotification {
	preferencesWindow = nil;
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