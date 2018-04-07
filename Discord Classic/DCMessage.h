//
//  DCMessage.h
//  Discord Classic
//
//  Created by Julian Triveri on 4/6/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCMessage : NSObject
//ID/snowflake
@property NSString* snowflake;
//author name of the message
@property NSString* authorName;
//content
@property NSString* content;
//image included in message
@property UIImage* embededImage;
//if the message includes an image
@property bool hasEmbededImage;

-(void)checkIfRead;
@end
