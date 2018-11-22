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
#import "DCMessage.h"

@interface DCChannel : NSObject <NSURLConnectionDelegate>
@property NSString* snowflake;
@property NSString* name;
@property NSString* lastMessageId;
@property NSString* lastReadMessageId;
@property bool unread;
@property bool muted;
@property int type;
@property DCGuild* parentGuild;

-(void)checkIfRead;
- (void)sendMessage:(NSString*)message;
- (void)ackMessage:(NSString*)message;
- (void)sendImage:(UIImage*)image;
- (NSArray*)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message;
@end
