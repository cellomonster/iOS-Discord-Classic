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

@interface DCChannel()

@property NSURLConnection *connection;

@end

@implementation DCChannel

-(NSString *)description{
	return [NSString stringWithFormat:@"[Channel] Snowflake: %@, Type: %i, Read: %d, Name: %@", self.snowflake, self.type, self.unread, self.name];
}

-(void)checkIfRead{
	self.unread = (!self.muted && self.lastReadMessageId != (id)NSNull.null && ![self.lastReadMessageId isEqualToString:self.lastMessageId]);
	[self.parentGuild checkIfRead];
}

- (void)sendMessage:(NSString*)message {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL* channelURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://discordapp.com/api/channels/%@/messages", self.snowflake]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1];
		
		NSString* messageString = [NSString stringWithFormat:@"{\"content\":\"%@\"}", message];
		
		[urlRequest setHTTPMethod:@"POST"];
		
		[urlRequest setHTTPBody:[NSData dataWithBytes:[messageString UTF8String] length:[messageString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]]];
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		[DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	});
}



- (void)sendImage:(UIImage*)image {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL* channelURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://discordapp.com/api/channels/%@/messages", self.snowflake]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
		
		[urlRequest setHTTPMethod:@"POST"];
		
		NSString *boundary = @"---------------------------14737809831466499882746641449";
		
		NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
		[urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		
		NSMutableData *postbody = NSMutableData.new;
		[postbody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[postbody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		[postbody appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[postbody appendData:[NSData dataWithData:UIImageJPEGRepresentation(image, 0.9f)]];
		[postbody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[postbody appendData:[@"Content-Disposition: form-data; name=\"content\"\r\n\r\n " dataUsingEncoding:NSUTF8StringEncoding]];
		[postbody appendData:[[NSString stringWithFormat:@"\r\n--%@--", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		
		[urlRequest setHTTPBody:postbody];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		[DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	});
}



- (void)ackMessage:(NSString*)messageId{
	self.lastReadMessageId = messageId;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	
		NSURL* channelURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://discordapp.com/api/channels/%@/messages/%@/ack", self.snowflake, messageId]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1];
		
		[urlRequest setHTTPMethod:@"POST"];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		[DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	});
}



- (NSArray*)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message{
	
	NSMutableArray* messages = NSMutableArray.new;
	
	//Generate URL from args
	NSMutableString* getChannelAddress = [[NSString stringWithFormat: @"https://discordapp.com/api/channels/%@/messages?", self.snowflake] mutableCopy];
	
	if(numberOfMessages)
		[getChannelAddress appendString:[NSString stringWithFormat:@"limit=%i", numberOfMessages]];
	if(numberOfMessages && message)
		[getChannelAddress appendString:@"&"];
	if(message)
		[getChannelAddress appendString:[NSString stringWithFormat:@"before=%@", message.snowflake]];
	
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:getChannelAddress] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2];
	
	[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
	[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	
	NSError *error;
	NSHTTPURLResponse *responseCode;
	NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
	
	if(response){
		NSArray* parsedResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
		
		if(parsedResponse.count > 0)
			for(NSDictionary* jsonMessage in parsedResponse)
				[messages insertObject:[DCTools convertJsonMessage:jsonMessage] atIndex:0];
		
		if(messages.count > 0)
			return messages;
		
		[DCTools alert:@"No messages!" withMessage:@"No further messages could be found"];
	}
	
	return nil;
}


@end
