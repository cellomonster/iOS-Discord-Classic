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
//ID/snowflake
@property NSString* snowflake;
//name
@property NSString* name;
//ID/snowflake of last message 
@property NSString* lastMessageId;
//ID/snowflake of last read message
@property NSString* lastReadMessageId;
//Whether or not the chnanel has been read
@property bool unread;
//Type of channel (voice, text, catagory, etc)
@property int type;

//Guild which the channel is a child of
@property DCGuild* parentGuild;

-(void)checkIfRead;
@end
