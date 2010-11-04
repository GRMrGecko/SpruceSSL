//
//  MGMWebViewMethods.m
//  SpruceSSL
//
//  Created by Mr. Gecko on 11/2/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import "MGMWebViewMethods.h"
#import "MGMSpruceSSL.h"

@implementation NSURLConnection (MGMWebViewMethods)
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately {
	return [self MGMInitWithRequest:[[MGMSpruceSSL sharedController] requestForRequest:request] delegate:delegate startImmediately:startImmediately];
}
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate {
	return [self MGMInitWithRequest:[[MGMSpruceSSL sharedController] requestForRequest:request] delegate:delegate];
}
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate priority:(float)priority {
	return [self MGMInitWithRequest:[[MGMSpruceSSL sharedController] requestForRequest:request] delegate:delegate priority:priority];
}
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate usesCache:(BOOL)usesCacheFlag maxContentLength:(long long)maxContentLength startImmediately:(BOOL)startImmediately connectionProperties:(NSDictionary *)connectionProperties {
	return [self MGMInitWithRequest:[[MGMSpruceSSL sharedController] requestForRequest:request] delegate:delegate usesCache:usesCacheFlag maxContentLength:maxContentLength startImmediately:startImmediately connectionProperties:connectionProperties];
}
@end