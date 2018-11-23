//
//  DCUser.m
//  Discord Classic
//
//  Created by Trevir on 11/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCUser.h"

@implementation DCUser

-(NSString *)description{
	return [NSString stringWithFormat:@"[User] Snowflake: %@, Username: %@", self.snowflake, self.username];
}
@end
