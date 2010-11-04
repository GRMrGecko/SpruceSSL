//
//  MGMWebViewMethods.h
//  SpruceSSL
//
//  Created by Mr. Gecko on 11/2/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import <Cocoa/Cocoa.h>
#import "Safari.h"
#import "MGMSpruceSSL.h"

@interface NSURLConnection (MGMWebViewMethods)
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately;
- (id)MGMInitWithRequest:(NSURLRequest *)request delegate:(id)delegate usesCache:(BOOL)usesCacheFlag maxContentLength:(long long)maxContentLength startImmediately:(BOOL)startImmediately connectionProperties:(NSDictionary *)connectionProperties;
@end