//
//  DCWebImageOperations.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCTools.h"
#import "DCMessage.h"
#import "DCUser.h"
#import "DCServerCommunicator.h"

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

+ (void)alert:(NSString*)title withMessage:(NSString*)message{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [UIAlertView.alloc
													initWithTitle: title
													message: message
													delegate: nil
													cancelButtonTitle:@"OK"
													otherButtonTitles:nil];
		[alert show];
	});
}



+ (NSData*)checkData:(NSData*)response withError:(NSError*)error{
	if(!response){
		[DCTools alert:error.localizedDescription withMessage:error.localizedRecoverySuggestion];
		return nil;
	}
	return response;
}

+ (DCMessage*)convertJsonMessage:(NSDictionary*)jsonMessage{
	DCMessage* newMessage = DCMessage.new;
	NSString* authorId = [jsonMessage valueForKeyPath:@"author.id"];
	
	if(![DCServerCommunicator.sharedInstance.loadedUsers objectForKey:authorId]){
		DCUser* newUser = DCUser.new;
		newUser.username = [jsonMessage valueForKeyPath:@"author.username"];
		newUser.snowflake = [jsonMessage valueForKeyPath:@"author.id"];
		
		NSString* avatarURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/avatars/%@/%@.png", newUser.snowflake, [jsonMessage valueForKeyPath:@"author.avatar"]];
		
		[DCTools processImageDataWithURLString:avatarURL andBlock:^(NSData *imageData){
			UIImage *retrievedImage = [UIImage imageWithData:imageData];
			
			if(retrievedImage != nil){
				newUser.profileImage = retrievedImage;
				[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD CHAT DATA" object:nil];
			}
			
		}];
		
		[DCServerCommunicator.sharedInstance.loadedUsers setValue:newUser forKey:newUser.snowflake];
	}
	
	newMessage.author = [DCServerCommunicator.sharedInstance.loadedUsers valueForKey:authorId];
	
	newMessage.content = [jsonMessage valueForKey:@"content"];
	newMessage.snowflake = [jsonMessage valueForKey:@"id"];
	newMessage.embeddedImages = NSMutableArray.new;
	newMessage.embeddedImageCount = 0;
	
	NSArray* embeds = [jsonMessage objectForKey:@"embeds"];
	
	if(embeds)
		for(NSDictionary* embed in embeds){
			NSString* embedType = [embed valueForKey:@"type"];
			if([embedType isEqualToString:@"image"]){
				newMessage.embeddedImageCount++;
				
				[DCTools processImageDataWithURLString:[embed valueForKeyPath:@"thumbnail.url"] andBlock:^(NSData *imageData){
					UIImage *retrievedImage = [UIImage imageWithData:imageData];
					
					if(retrievedImage != nil){
						[newMessage.embeddedImages addObject:retrievedImage];
						[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD CHAT DATA" object:nil];
					}
					
				}];
			}
		}
	
	NSArray* attachments = [jsonMessage objectForKey:@"attachments"];
	if(attachments)
		for(NSDictionary* attachment in attachments){
			newMessage.embeddedImageCount++;
			
			[DCTools processImageDataWithURLString:[attachment valueForKey:@"url"] andBlock:^(NSData *imageData){
				UIImage *retrievedImage = [UIImage imageWithData:imageData];
				
				if(retrievedImage != nil){
					[newMessage.embeddedImages addObject:retrievedImage];
					[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD CHAT DATA" object:nil];
				}
			}];
		}
	
	
	float contentWidth = [UIScreen mainScreen].bounds.size.width - 66;
	
	CGSize authorNameSize = [newMessage.author.username sizeWithFont:[UIFont boldSystemFontOfSize:15] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	CGSize contentSize = [newMessage.content sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	
	newMessage.contentHeight = authorNameSize.height + contentSize.height + 10;
	
	return newMessage;
}
@end
