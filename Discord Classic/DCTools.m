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

//https://discord.gg/X4NSsMC

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

//Returns a parsed NSDictionary from a json string or nil if something goes wrong
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

//Used when making http requests
+ (NSData*)checkData:(NSData*)response withError:(NSError*)error{
	if(!response){
		[DCTools alert:error.localizedDescription withMessage:error.localizedRecoverySuggestion];
		return nil;
	}
	return response;
}






//Converts an NSDictionary created from json representing a user into a DCUser object
//Also keeps the user in DCServerCommunicator.loadedUsers if cache:YES
+ (DCUser*)convertJsonUser:(NSDictionary*)jsonUser cache:(bool)cache{
	
	DCUser* newUser = DCUser.new;
	newUser.username = [jsonUser valueForKey:@"username"];
	newUser.snowflake = [jsonUser valueForKey:@"id"];
	
	//Load profile image
	NSString* avatarURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/avatars/%@/%@.png", newUser.snowflake, [jsonUser valueForKey:@"avatar"]];
	[DCTools processImageDataWithURLString:avatarURL andBlock:^(NSData *imageData){
		UIImage *retrievedImage = [UIImage imageWithData:imageData];
		
		if(retrievedImage != nil){
			newUser.profileImage = retrievedImage;
			[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD CHAT DATA" object:nil];
		}
		
	}];
	
	//Save to DCServerCOmmunicator.loadedUsers
	if(cache)
		[DCServerCommunicator.sharedInstance.loadedUsers setValue:newUser forKey:newUser.snowflake];
	
	return newUser;
}





//Converts an NSDictionary created from json representing a message into a message object
+ (DCMessage*)convertJsonMessage:(NSDictionary*)jsonMessage{
	DCMessage* newMessage = DCMessage.new;
	NSString* authorId = [jsonMessage valueForKeyPath:@"author.id"];
	
	if(![DCServerCommunicator.sharedInstance.loadedUsers objectForKey:authorId])
		[DCTools convertJsonUser:[jsonMessage valueForKeyPath:@"author"] cache:true];
	
	newMessage.author = [DCServerCommunicator.sharedInstance.loadedUsers valueForKey:authorId];
	
	newMessage.content = [jsonMessage valueForKey:@"content"];
	newMessage.snowflake = [jsonMessage valueForKey:@"id"];
	newMessage.embeddedImages = NSMutableArray.new;
	newMessage.embeddedImageCount = 0;
	
	//Load embeded images from both links and attatchments
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
	
	//Parse in-text mentions into readable @<username>
	NSArray* mentions = [jsonMessage objectForKey:@"mentions"];
	
	if(mentions.count){
		
		for(NSDictionary* mention in mentions){
			if(![DCServerCommunicator.sharedInstance.loadedUsers valueForKey:[mention valueForKey:@"id"]]){
				[DCTools convertJsonUser:mention cache:true];
			}
		}
		
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\<@(.*?)\\>" options:NSRegularExpressionCaseInsensitive error:NULL];
		
		NSTextCheckingResult *embededMention = [regex firstMatchInString:newMessage.content options:0 range:NSMakeRange(0, newMessage.content.length)];
		
		while(embededMention){
			
			NSCharacterSet *charactersToRemove = [NSCharacterSet.alphanumericCharacterSet invertedSet];
			NSString *mentionSnowflake = [[[newMessage.content substringWithRange:embededMention.range] componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@""];
			
			NSLog(@"%@", mentionSnowflake);
			
			DCUser *user = [DCServerCommunicator.sharedInstance.loadedUsers valueForKey:mentionSnowflake];
			
			NSString* username = @"@MENTION";
			
			if(user)
				username = [NSString stringWithFormat:@"@%@", user.username];
			
			newMessage.content = [newMessage.content stringByReplacingCharactersInRange:embededMention.range withString:username];
			
			embededMention = [regex firstMatchInString:newMessage.content options:0 range:NSMakeRange(0, newMessage.content.length)];
		}
	}
	
	//Calculate height of content to be used when showing messages in a tableview
	//contentHeight does NOT include height of the embeded images
	float contentWidth = UIScreen.mainScreen.bounds.size.width - 63;
	
	CGSize authorNameSize = [newMessage.author.username sizeWithFont:[UIFont boldSystemFontOfSize:15] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	CGSize contentSize = [newMessage.content sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(contentWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	
	newMessage.contentHeight = authorNameSize.height + contentSize.height + 10;
	
	return newMessage;
}





+(DCGuild *)convertJsonGuild:(NSDictionary*)jsonGuild{
	NSMutableArray* userRoles;
	
	//Get roles of the current user
	for(NSDictionary* member in [jsonGuild objectForKey:@"members"])
		if([[member valueForKeyPath:@"user.id"] isEqualToString:DCServerCommunicator.sharedInstance.snowflake])
			userRoles = [[member valueForKey:@"roles"] mutableCopy];
	
	//Get @everyone role
	for(NSDictionary* guildRole in [jsonGuild objectForKey:@"roles"])
		if([[guildRole valueForKey:@"name"] isEqualToString:@"@everyone"])
			[userRoles addObject:[guildRole valueForKey:@"id"]];
	
	DCGuild* newGuild = DCGuild.new;
	newGuild.name = [jsonGuild valueForKey:@"name"];
	newGuild.snowflake = [jsonGuild valueForKey:@"id"];
	newGuild.channels = NSMutableArray.new;
	
	NSString* iconURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/icons/%@/%@",
											 newGuild.snowflake, [jsonGuild valueForKey:@"icon"]];
	
	[DCTools processImageDataWithURLString:iconURL andBlock:^(NSData *imageData) {
		newGuild.icon = [UIImage imageWithData:imageData];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD GUILD LIST" object:DCServerCommunicator.sharedInstance];
		});
		
	}];
	
	for(NSDictionary* jsonChannel in [jsonGuild valueForKey:@"channels"]){
		
		//Make sure jsonChannel is a text cannel
		//we dont want to include voice channels in the text channel list
		if([[jsonChannel valueForKey:@"type"] isEqual: @0]){
			
			//Allow code is used to determine if the user should see the channel in question.
			/*
			 0 - No overwrides. Channel should be created
			 
			 1 - Hidden by role. Channel should not be created unless another role contradicts (code 2)
			 2 - Shown by role. Channel should be created unless hidden by member overwride (code 3)
			 
			 3 - Hidden by member. Channel should not be created
			 4 - Shown by member. Channel should be created
			 
			 3 & 4 are mutually exclusive
			 */
			int allowCode = 0;
			
			//Calculate permissions
			for(NSDictionary* permission in [jsonChannel objectForKey:@"permission_overwrites"]){
				
				//Type of permission can either be role or member
				NSString* type = [permission valueForKey:@"type"];
				
				if([type isEqualToString:@"role"]){
					
					//Check if this channel dictates permissions over any roles the user has
					if([userRoles containsObject:[permission valueForKey:@"id"]]){
						int deny = [[permission valueForKey:@"deny"] intValue];
						int allow = [[permission valueForKey:@"allow"] intValue];
						
						if((deny & 1024) == 1024 && allowCode < 1)
							allowCode = 1;
						
						if(((allow & 1024) == 1024) && allowCode < 2)
							allowCode = 2;
					}
				}
				
				
				if([type isEqualToString:@"member"]){
					
					//Check if
					NSString* memberId = [permission valueForKey:@"id"];
					if([memberId isEqualToString:DCServerCommunicator.sharedInstance.snowflake]){
						int deny = [[permission valueForKey:@"deny"] intValue];
						int allow = [[permission valueForKey:@"allow"] intValue];
						
						if((deny & 1024) == 1024 && allowCode < 3)
							allowCode = 3;
						
						if((allow & 1024) == 1024){
							allowCode = 4;
							break;
						}
					}
				}
			}
			
			if(allowCode == 0 || allowCode == 2 || allowCode == 4){
				DCChannel* newChannel = DCChannel.new;
				
				newChannel.snowflake = [jsonChannel valueForKey:@"id"];
				newChannel.name = [jsonChannel valueForKey:@"name"];
				newChannel.lastMessageId = [jsonChannel valueForKey:@"last_message_id"];
				newChannel.parentGuild = newGuild;
				newChannel.type = 0;
				
				if([DCServerCommunicator.sharedInstance.userChannelSettings objectForKey:newChannel.snowflake])
					newChannel.muted = true;
				
				//check if channel is muted
				
				[newGuild.channels addObject:newChannel];
				[DCServerCommunicator.sharedInstance.channels setObject:newChannel forKey:newChannel.snowflake];
			}
		}
	}
	
	return newGuild;
}





+ (void)joinGuild:(NSString*)inviteCode {
		NSURL* guildURL = [NSURL URLWithString: [NSString stringWithFormat:@"https://discordapp.com/api/v6/invite/%@", inviteCode]];
		
		NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:guildURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1];
		
		[urlRequest setHTTPMethod:@"POST"];
		
		//[urlRequest setHTTPBody:[NSData dataWithBytes:[messageString UTF8String] length:[messageString length]]];
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		
		NSError *error = nil;
		NSHTTPURLResponse *responseCode = nil;
		
		[DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];
}

@end