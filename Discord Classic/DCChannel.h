//
//  DCChannel.h
//  Discord Classic
//
//  Created by Julian Triveri on 3/12/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

/*DCChannel is a representation of a Discord API Channel object.
 Its easier to work with than raw JSON data and has some handy
 built in functions*/

#import <Foundation/Foundation.h>
#import "DCGuild.h"

@interface DCChannel : NSObject
@property NSString* snowflake;
@property NSString* name;
@property NSString* lastMessageId;
@property NSString* lastReadMessageId;
@property bool unread;
@property bool muted;
@property int type;
@property DCGuild* parentGuild;

-(void)checkIfRead;
- (NSDictionary*)sendMessage:(NSString*)message;
- (NSDictionary*)ackMessage:(NSString*)message;
@end
