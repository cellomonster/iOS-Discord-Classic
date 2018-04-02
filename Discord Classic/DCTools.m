//
//  DCWebImageOperations.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCTools.h"

@implementation DCTools
+ (void)processImageDataWithURLString:(NSString *)urlString
														 andBlock:(void (^)(NSData *imageData))processImage{
	
	NSURL *url = [NSURL URLWithString:urlString];
	
	dispatch_queue_t callerQueue = dispatch_get_current_queue();
	dispatch_queue_t downloadQueue = dispatch_queue_create("com.discord_classic.processsmagequeue", NULL);
	dispatch_async(downloadQueue, ^{
		NSData* imageData = [NSData dataWithContentsOfURL:url];
		
		dispatch_async(callerQueue, ^{
			processImage(imageData);
		});
	});
	dispatch_release(downloadQueue);
}

+ (NSDictionary*)parseJSON:(NSString*)json{
	NSError *error = nil;
	NSData *encodedResponseString = [json dataUsingEncoding:NSUTF8StringEncoding];
	id parsedResponse = [NSJSONSerialization JSONObjectWithData:encodedResponseString options:0 error:&error];
	if([parsedResponse isKindOfClass:NSDictionary.class]){
		return parsedResponse;
	}
	return nil;
}
@end
