//
//  DCWebImageOperations.h
//  Discord Classic
//
//  Created by Julian Triveri on 3/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCTools : NSObject
+ (void)processImageDataWithURLString:(NSString *)urlString
														 andBlock:(void (^)(NSData *imageData))processImage;

+ (NSDictionary*)parseJSON:(NSString*)json;
+ (void)errorAlert:(NSError*)error;
+ (NSData*)checkData:(NSData*)response withError:(NSError*)error;
@end
