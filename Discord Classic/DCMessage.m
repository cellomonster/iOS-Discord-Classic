//
//  DCMessage.m
//  Discord Classic
//
//  Created by Julian Triveri on 4/7/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCMessage.h"
#import "DCServerCommunicator.h"
#import "DCTools.h"

@implementation DCMessage

- (void)deleteMessage{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL* messageURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://discordapp.com/api/v6/channels/%@/messages/%@", DCServerCommunicator.sharedInstance.selectedChannel.snowflake, self.snowflake]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:messageURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1];
		
		[urlRequest setHTTPMethod:@"DELETE"];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		[DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	});
}

- (BOOL)isEqual:(id)other{
	if (!other || ![other isKindOfClass:DCMessage.class])
		return NO;
	
	return [self.snowflake isEqual:((DCMessage*)other).snowflake];
}

@end
