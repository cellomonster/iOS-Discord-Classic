//
//  DCWebImageOperations.h
//  Discord Classic
//
//  Created by Julian Triveri on 3/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCMessage.h"

@interface DCTools : NSObject
+ (void)processImageDataWithURLString:(NSString *)urlString
														 andBlock:(void (^)(NSData *imageData))processImage;

+ (NSDictionary*)parseJSON:(NSString*)json;
+ (void)alert:(NSString*)title withMessage:(NSString*)message;
+ (NSData*)checkData:(NSData*)response withError:(NSError*)error;
+ (DCMessage*)convertJsonMessage:(NSDictionary*)jsonMessage;
@end
