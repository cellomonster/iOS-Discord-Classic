//
//  DCChannel.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/12/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCChannel.h"
#import "DCServerCommunicator.h"
#import "DCTools.h"

@implementation DCChannel


-(NSString *)description{
	return [NSString stringWithFormat:@"[Channel] Snowflake: %@, Type: %i, Read: %d, Name: %@", self.snowflake, self.type, self.unread, self.name];
}

-(void)checkIfRead{
	self.unread = (!self.muted && self.lastReadMessageId != (id)NSNull.null && ![self.lastReadMessageId isEqualToString:self.lastMessageId]);
	
	[self.parentGuild checkIfRead];
}

- (NSDictionary*)sendMessage:(NSString*)message {
	
	NSURL* channelURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://discordapp.com/api/channels/%@/messages", self.snowflake]];
	
	NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
	
	NSString* messageString = [NSString stringWithFormat:@"{\"content\":\"%@\"}", message];
	
	[urlRequest setHTTPBody:[NSData dataWithBytes:[messageString UTF8String] length:[messageString length]]];
	[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
	[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPMethod:@"POST"];
	
	
	NSError *error = nil;
	NSHTTPURLResponse *responseCode = nil;
	
	NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	
	if(response)
		return [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
	return nil;
}

- (NSDictionary*)ackMessage:(NSString*)messageId{
	
	if(messageId != (id)NSNull.null){
		self.lastReadMessageId = messageId;
		
		NSURL* channelURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://discordapp.com/api/channels/%@/messages/%@/ack", self.snowflake, messageId]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		[urlRequest setHTTPMethod:@"POST"];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
		
		if(response)
			return [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
	}
	return nil;
}


@end
