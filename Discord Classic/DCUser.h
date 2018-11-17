//
//  DCUser.h
//  Discord Classic
//
//  Created by Trevir on 11/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCUser : NSObject
@property NSString* snowflake;
@property NSString* username;
@property UIImage* profileImage;

-(NSString *)description;
@end
