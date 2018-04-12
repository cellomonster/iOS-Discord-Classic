//
//  DCMessage.h
//  Discord Classic
//
//  Created by Julian Triveri on 4/6/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCMessage : NSObject
@property NSString* snowflake;
@property NSString* authorName;
@property NSString* content;
@property UIImage* embededImage;
@property bool hasEmbededImage;

-(void)checkIfRead;
@end
