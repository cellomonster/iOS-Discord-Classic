//
//  DCServerCommunicator.h
//  Discord Classic
//
//  Created by Julian Triveri on 3/4/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WSWebSocket.h"
#import "DCGuildListViewController.h"
#import "DCChannelListViewController.h"
#import "DCChatViewController.h"

@interface DCServerCommunicator : NSObject
@property bool isReconnecting;

@property WSWebSocket* websocket;
@property NSString* token;
@property NSString* gatewayURL;
@property NSMutableArray* guilds;
@property NSMutableDictionary* channels;
@property DCChannel* selectedChannel;

+ (DCServerCommunicator *)sharedInstance;
- (void)startCommunicator;
- (void)sendResume;
- (void)reconnect;
- (void)sendHeartbeat:(NSTimer *)timer;
- (void)sendJSON:(NSDictionary*)dictionary;
- (NSDictionary*)sendMessage:(NSString*)message inChannel:(DCChannel*)channel;
- (NSDictionary*)ackMessage:(NSString*)messageId inChannel:(DCChannel*)channel;
@end
