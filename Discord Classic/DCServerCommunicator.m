//
//  DCServerCommunicator.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/4/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCServerCommunicator.h"
#import "DCGuild.h"
#import "DCChannel.h"
#import "DCTools.h"

@interface DCServerCommunicator()
@property bool didRecieveHeartbeatResponse;
@property bool shouldResume;
@property bool heartbeatDefined;

@property bool botAccount;

@property int sequenceNumber;
@property NSString* sessionId;

@property NSString* snowflake;

@property UIAlertView* alertView;
@end


@implementation DCServerCommunicator

+ (DCServerCommunicator *)sharedInstance {
	
	static DCServerCommunicator *sharedInstance = nil;
	
	if (sharedInstance == nil) {
		sharedInstance = DCServerCommunicator.new;
	}
	
	return sharedInstance;
}

- (void)startCommunicator{
	
	self.botAccount = false;
	
	//To prevent retain cycle
	__weak typeof(self) weakSelf = self;
	
	self.didRecieveHeartbeatResponse = true;
	
	NSString* token = [NSUserDefaults.standardUserDefaults stringForKey:@"token"];
	
	if(token!=nil){
		
		//Close possible previous session
		if(!self.shouldResume)
			[self.websocket close];
		
		self.token = token;
		self.gatewayURL = @"wss://gateway.discord.gg/?encoding=json&v=6";
		
		//Establish websocket connection with Discord
		NSURL *websocketUrl = [NSURL URLWithString:self.gatewayURL];
		self.websocket = [WSWebSocket.alloc initWithURL:websocketUrl protocols:nil];
		
		[self.websocket setTextCallback:^(NSString *responseString) {
			
			//Parse JSON to a dictionary
			NSDictionary *parsedWebsocketResponse = [DCTools parseJSON:responseString];
			
			//Data values for easy access
			int op = [[parsedWebsocketResponse valueForKey:@"op"] integerValue];
			NSDictionary* d = [parsedWebsocketResponse valueForKey:@"d"];
			
			//Dictionary that will be used to send information via websocket
			NSDictionary *userInfo;
			
			NSLog(@"Got op code %i", op);
			
			
			if(op == 10){
				if(self.shouldResume){
					
					NSLog(@"Sending Resume %i %@", self.sequenceNumber, self.sessionId);
					
					userInfo = @{
					@"op":@6,
					@"d":@{
					@"token":self.token,
					@"session_id":self.sessionId,
					@"seq":@(self.sequenceNumber),
					}
					};
					
					self.shouldResume = false;
					
				}else{
					
					int heartbeatInterval = [[d valueForKey:@"heartbeat_interval"] intValue];
					
					//Send a heartbeat at interval heartbeatinterval
					if(!self.heartbeatDefined){
						self.heartbeatDefined = true;
						NSLog(@"Defined heartbeat");
						dispatch_async(dispatch_get_main_queue(), ^{
							
							[NSTimer scheduledTimerWithTimeInterval:heartbeatInterval/1000
																							 target:weakSelf
																						 selector:@selector(sendHeartbeat:)
																						 userInfo:nil
																							repeats:YES];
						});
					}
					
					NSLog(@"Sending Identify");
					userInfo = @{
					@"op":@2,
					@"d":@{
					@"token":self.token,
					@"properties":@{ @"$browser" : @"peble" },
					@"large_threshold":@"50",
					}
					};
					
				}
				
				[weakSelf sendJSON:userInfo];
			}
			
			
			//Event
			if(op == 0){
				
				//Get event type and sequence number
				NSString* t = [parsedWebsocketResponse valueForKey:@"t"];
				self.sequenceNumber = [[parsedWebsocketResponse valueForKey:@"s"] integerValue];
				NSLog(@"Got event %@ with sequence number %i", t, self.sequenceNumber);
				
				if([t isEqualToString:@"READY"] && !self.botAccount){
					
					self.isReconnecting = false;
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.alertView dismissWithClickedButtonIndex:0 animated:YES];
					});
					
					self.sessionId = [d valueForKey:@"session_id"];
					NSLog(@"Got session ID %@", self.sessionId);
					
					NSDictionary* user = [d objectForKey:@"user"];
					self.snowflake = [user valueForKey:@"id"];
					
					self.guilds = NSMutableArray.new;
					self.channels = NSMutableDictionary.new;
					
					NSMutableArray* newChannels = NSMutableArray.new;
					
					//Take care of private channels (direct messages)
					//The user's DMs are treated like a guild, where the channels are different DM/groups
					DCGuild* privateGuild = DCGuild.new;
					privateGuild.name = @"Direct Messages";
					
					NSArray* privateChannels = [d valueForKey:@"private_channels"];
					
					for(NSDictionary* privateChannel in privateChannels){
						DCChannel* newChannel = DCChannel.new;
						newChannel.snowflake = [privateChannel valueForKey:@"id"];
						
						NSString* privateChannelName = [privateChannel valueForKey:@"name"];
						
						//Some private channels dont have names, check if nil
						if(privateChannelName!=(id)NSNull.null && privateChannelName)
							
							newChannel.name = privateChannelName;
						
						else{
							//If no name, create a name from member or list of members
							NSString* fullChannelName = @"";
							NSArray* privateChannelMembers = [privateChannel valueForKey:@"recipients"];
							
							if(privateChannelMembers.count){
								
								for(NSDictionary* privateChannelMember in privateChannelMembers){
									//add , between member names
									if([privateChannelMembers indexOfObject:privateChannelMember] != 0)
										fullChannelName = [fullChannelName stringByAppendingString:@", "];
									
									NSString* memberName = [privateChannelMember valueForKey:@"username"];
									fullChannelName = [fullChannelName stringByAppendingString:memberName];
									
									newChannel.name = fullChannelName;
								}
							}
						}
						
						newChannel.lastMessageId = [privateChannel valueForKey:@"last_message_id"];
						newChannel.parentGuild = privateGuild;
						newChannel.type = 1;
						
						[newChannels addObject:newChannel];
						[self.channels setObject:newChannel forKey:newChannel.snowflake];
					}
					privateGuild.channels = newChannels;
					[self.guilds addObject:privateGuild];
					
					
					
					//Take care of normal guilds (servers)
					NSArray* jsonGuilds = [d valueForKey:@"guilds"];
					if(jsonGuilds){
						
						for(NSDictionary* jsonGuild in jsonGuilds){
							
							NSMutableArray* userRoles;
							
							//Get roles of the current user
							NSArray* members = [jsonGuild objectForKey:@"members"];
							if(members)
								for(NSDictionary* member in members){
									
									NSDictionary* memberInfo = [member objectForKey:@"user"];
									NSString* memberId = [memberInfo valueForKey:@"id"];
									
									if([memberId isEqualToString:self.snowflake])
										userRoles = [[member valueForKey:@"roles"] mutableCopy];
								}
							
							//Get @everyone role
							NSArray* guildRoles = [jsonGuild objectForKey:@"roles"];
							for(NSDictionary* guildRole in guildRoles){
								
								NSString* guildRoleName = [guildRole valueForKey:@"name"];
								if([guildRoleName isEqualToString:@"@everyone"]){
									
									NSString* everyoneRoleId = [guildRole valueForKey:@"id"];
									[userRoles addObject:everyoneRoleId];
								}
							}
						
							//Create array of json channels from the current json guild
							NSArray* jsonChannelsArray = [jsonGuild valueForKey:@"channels"];
							
							if(jsonChannelsArray){
								
								DCGuild* newGuild = DCGuild.new;
								
								//We will pass this array into our new guild object later. This is an array of that guild's channels
								newChannels = NSMutableArray.new;
								
								for(NSDictionary* jsonChannel in jsonChannelsArray){
									
									//Check if text channel
									if([jsonChannel valueForKey:@"type"] == @0){
										
										NSArray* permissions = [jsonChannel objectForKey:@"permission_overwrites"];
										
										bool shouldCreateChannel = true;
										
										//Calculate permissions
										//The next 4 for loops are written incredibly shitty and should be consolidated into only 1
										for(NSDictionary* permission in permissions){
											
											NSString* type = [permission valueForKey:@"type"];
											
											bool hasRole = false;
											
											if([type isEqualToString:@"role"]){
												NSString* roleId = [permission valueForKey:@"id"];
												for(NSString* snowflake in userRoles){
													if([snowflake isEqualToString:roleId]){
														hasRole = true;
													}
												}
											}
											
											int deny = [[permission valueForKey:@"deny"] intValue];
											NSLog(@"Deny %i %@", deny & 1024, [jsonChannel valueForKey:@"name"]);
											
											if(hasRole){
												if(((deny & 1024) == 1024)){
													shouldCreateChannel = false;
												}
											}
										}
										
										for(NSDictionary* permission in permissions){
											NSString* type = [permission valueForKey:@"type"];
											
											bool hasRole = false;
											
											if([type isEqualToString:@"role"]){
												NSString* roleId = [permission valueForKey:@"id"];
												for(NSString* snowflake in userRoles){
													if([snowflake isEqualToString:roleId]){
														hasRole = true;
													}
												}
											}
											
											int allow = [[permission valueForKey:@"allow"] intValue];
											if(hasRole){
												if(((allow & 1024) == 1024)){
													shouldCreateChannel = true;
												}
											}
											NSLog(@"Allow %i %@", allow & 1024, [jsonChannel valueForKey:@"name"]);
											NSLog(@"%@", permission);
										}
										
										for(NSDictionary* permission in permissions){
											NSString* type = [permission valueForKey:@"type"];
											
											bool hasRole = false;
											
											if([type isEqualToString:@"member"]){
												NSString* memberId = [permission valueForKey:@"id"];
												for(NSString* snowflake in userRoles){
													if([self.snowflake isEqualToString:memberId]){
														hasRole = true;
													}
												}
											}
											
											int deny = [[permission valueForKey:@"deny"] intValue];
											NSLog(@"Deny %i %@", deny & 1024, [jsonChannel valueForKey:@"name"]);
											
											if(hasRole){
												if(((deny & 1024) == 1024)){
													shouldCreateChannel = false;
												}
											}
										}
										
										for(NSDictionary* permission in permissions){
											NSString* type = [permission valueForKey:@"type"];
											
											bool hasRole = false;
											
											if([type isEqualToString:@"member"]){
												NSString* memberId = [permission valueForKey:@"id"];
												for(NSString* snowflake in userRoles){
													if([self.snowflake isEqualToString:memberId]){
														hasRole = true;
													}
												}
											}
											
											int allow = [[permission valueForKey:@"allow"] intValue];
											NSLog(@"Allow %i %@", allow & 1024, [jsonChannel valueForKey:@"name"]);
											
											if(hasRole){
												if(((allow & 1024) == 1024)){
													shouldCreateChannel = true;
												}
											}
										}
										
										if(shouldCreateChannel){
											DCChannel* newChannel = DCChannel.new;
											
											newChannel.snowflake = [jsonChannel valueForKey:@"id"];
											newChannel.name = [jsonChannel valueForKey:@"name"];
											newChannel.lastMessageId = [jsonChannel valueForKey:@"last_message_id"];
											newChannel.parentGuild = newGuild;
											newChannel.type = 0;
											
											//Add that channel to the channels array for the new guild
											[newChannels addObject:newChannel];
											[self.channels setObject:newChannel forKey:newChannel.snowflake];
											
											//NSLog(@"Created new channel object: %@", newChannel);
											
										}
									}
								}
								
								//Set the guild details
								newGuild.snowflake = [jsonGuild valueForKey:@"id"];
								newGuild.name = [jsonGuild valueForKey:@"name"];
								newGuild.channels = newChannels;
								
								NSString* iconURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/icons/%@/%@",
																		 newGuild.snowflake, [jsonGuild valueForKey:@"icon"]];
								
								[DCTools processImageDataWithURLString:iconURL andBlock:^(NSData *imageData) {
									newGuild.icon = [UIImage imageWithData:imageData];
									
									dispatch_async(dispatch_get_main_queue(), ^{
										[NSNotificationCenter.defaultCenter postNotificationName:@"RELOAD GUILD LIST" object:weakSelf];
									});
									
								}];
								
								//NSLog(@"Created new guild object: %@", newGuild);
								
								//Add it to our communicator guild array
								[self.guilds addObject:newGuild];
							}
						}
					}
					
					
					//Read states are recieved in READY payload
					//they give a channel ID and the ID of the last read message in that channel
					NSArray* readstatesArray = [d valueForKey:@"read_state"];
					
					for(NSDictionary* readstate in readstatesArray){
						
						NSString* readstateChannelId = [readstate valueForKey:@"id"];
						NSString* readstateMessageId = [readstate valueForKey:@"last_message_id"];
						
						//Get the channel with the ID of readStateChannelId
						DCChannel* channelOfReadstate = [self.channels objectForKey:readstateChannelId];
						
						channelOfReadstate.lastReadMessageId = readstateMessageId;
						[channelOfReadstate checkIfRead];
					}
					
					//Now that that's all done,
					//send a notification that we successfully created our guild objects
					dispatch_async(dispatch_get_main_queue(), ^{
						[NSNotificationCenter.defaultCenter postNotificationName:@"READY" object:weakSelf];
					});
				}
				
				
				if([t isEqualToString:@"MESSAGE_ACK"])
					[NSNotificationCenter.defaultCenter postNotificationName:@"MESSAGE ACK" object:weakSelf];
				
				
				if([t isEqualToString:@"MESSAGE_CREATE"]){
					
					NSString* channelIdOfMessage = [d objectForKey:@"channel_id"];
					NSString* messageId = [d objectForKey:@"id"];
					
					//Check if a channel is currently being viewed
					//and if so, if that channel is the same the message was sent in
					if(self.selectedChannel != nil
						 && [channelIdOfMessage isEqualToString:self.selectedChannel.snowflake]){
						
						
						NSString* messageAuthorName = [d valueForKeyPath:@"author.username"];
						NSString* messageContent = [d objectForKey:@"content"];
						NSString* message = [NSString stringWithFormat:@"\n%@\n%@\n", messageAuthorName, messageContent];
						
						NSDictionary* userInfo = @{@"message": message};
						
						dispatch_async(dispatch_get_main_queue(), ^{
							//Send notification with the new message
							[NSNotificationCenter.defaultCenter postNotificationName:@"MESSAGE CREATE" object:weakSelf userInfo:userInfo];
						});
						
						//Update current channel & read state last message
						[self.selectedChannel setLastMessageId:messageId];
						
						NSLog(@"The message recieved was sent in the current channel");
						
						//Ack message since we are currently viewing this channel
						[weakSelf ackMessage:messageId inChannel:weakSelf.selectedChannel];
					}else{
						DCChannel* channelOfMessage = [self.channels objectForKey:channelIdOfMessage];
						channelOfMessage.lastMessageId = messageId;
						
						[channelOfMessage checkIfRead];
						
						dispatch_async(dispatch_get_main_queue(), ^{
							[NSNotificationCenter.defaultCenter postNotificationName:@"MESSAGE ACK" object:weakSelf];
						});
					}
					NSLog(@"The message recieved was NOT sent in the current channel");
				}
			}
			
			
			if(op == 11){
				self.didRecieveHeartbeatResponse = true;
				NSLog(@"Got heartbeat response");
			}
			
			if(op == 9){
				dispatch_async(dispatch_get_main_queue(), ^{
					[weakSelf reconnect];
				});
			}
		}];
		
		[self.websocket open];
	}
}


- (void)sendResume{
	self.shouldResume = true;
	[self startCommunicator];
}


-(void)reconnect{
	[self.websocket close];
	if(!self.isReconnecting){
		self.isReconnecting = true;
		[self performSelector:@selector(startCommunicator)
							 withObject:nil
							 afterDelay:5];
		
		
		self.alertView = [UIAlertView.alloc initWithTitle:@"Reconnecting"
																							message:@"\n"
																						 delegate:self
																		cancelButtonTitle:nil
																		otherButtonTitles:nil];
		
		UIActivityIndicatorView *spinner = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		spinner.center = CGPointMake(139.5, 75.5);
		
		[self.alertView addSubview:spinner];
		[spinner startAnimating];
		
		[self.alertView show];
	}
}


- (void)sendHeartbeat:(NSTimer *)timer{
	if(self.didRecieveHeartbeatResponse){
		[self sendJSON:@{ @"op": @1, @"d": @(self.sequenceNumber)}];
		NSLog(@"Sent heartbeat");
		[self setDidRecieveHeartbeatResponse:false];
	}else{
		NSLog(@"Did not get heartbeat response, sending RESUME with sequence %i %@", self.sequenceNumber, self.sessionId);
		[self sendResume];
	}
}


- (void)sendJSON:(NSDictionary*)dictionary{
	NSError *writeError = nil;
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
																										 options:NSJSONWritingPrettyPrinted
																											 error:&writeError];
	
	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	[self.websocket sendText:jsonString];
}


- (NSDictionary*)sendMessage:(NSString*)message inChannel:(DCChannel*)channel{
	
	NSURL* channelURL = [NSURL URLWithString:
											 [NSString stringWithFormat:@"%@%@%@",
												@"https://discordapp.com/api/channels/",
												channel.snowflake,
												@"/messages"]];
	
	NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL
																													cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
																											timeoutInterval:5];
	
	NSString* messageString = [NSString stringWithFormat:@"{\"content\":\"%@\"}", message];
	
	[urlRequest setHTTPBody:[NSData dataWithBytes:[messageString UTF8String] length:[messageString length]]];
	[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
	[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPMethod:@"POST"];
	
	
	NSError *error = nil;
	NSHTTPURLResponse *responseCode = nil;
	
	NSData *response = [NSURLConnection sendSynchronousRequest:urlRequest
																					 returningResponse:&responseCode
																											 error:&error];
	
	return [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
}


- (NSDictionary*)ackMessage:(NSString*)messageId inChannel:(DCChannel*)channel{
	
	NSURL* channelURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@%@%@",
																						@"https://discordapp.com/api/channels/",
																						channel.snowflake, @"/messages/",
																						messageId,
																						@"/ack"]];
	
	NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:channelURL
																													cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
																											timeoutInterval:5];
	
	[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
	[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPMethod:@"POST"];
	
	
	NSError *error = nil;
	NSHTTPURLResponse *responseCode = nil;
	
	NSData *response = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error];
	
	return [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
}

@end
