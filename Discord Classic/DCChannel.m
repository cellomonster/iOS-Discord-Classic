//
//  DCChannel.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/12/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCChannel.h"
#import "DCServerCommunicator.h"

@implementation DCChannel


-(NSString *)description{
	return [NSString stringWithFormat:@"[Channel] Snowflake: %@, Type: %i, Read: %d, Name: %@", self.snowflake, self.type, self.unread, self.name];
}

-(void)checkIfRead{
	self.unread = (!self.muted && self.lastReadMessageId != (id)NSNull.null && ![self.lastReadMessageId isEqualToString:self.lastMessageId]);
	
	NSLog(@"%@, %d", self.name, self.unread);
	
	[self.parentGuild checkIfRead];
}

@end
