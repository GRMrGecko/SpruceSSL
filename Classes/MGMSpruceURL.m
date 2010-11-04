//
//  MGMSpruceURL.m
//  SpruceSSL
//
//  Created by Mr. Gecko on 11/2/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import "MGMSpruceURL.h"

@implementation MGMSpruceURL
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	if ([[[[request URL] scheme] lowercaseString] isEqualToString:@"sprucessl"])
		return YES;
	return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
	return request;
}

- (void)startLoading {
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[[self request] URL] MIMEType:@"text/html" expectedContentLength:0 textEncodingName:nil];
	NSMutableURLRequest *request = [[self request] mutableCopy];
	NSString *url = [[request URL] absoluteString];
	NSRange range = [url rangeOfString:@":"];
	url = [@"https" stringByAppendingString:[url substringFromIndex:range.location]];
	[request setURL:[NSURL URLWithString:url]];
	
	id<NSURLProtocolClient> client = [self client];
	[client URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
	[client URLProtocolDidFinishLoading:self];
	
	[request release];
	[response release];
}
- (void)stopLoading {
	
}
@end