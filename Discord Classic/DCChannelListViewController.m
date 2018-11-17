//
//  DCChannelViewController.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/5/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCChannelListViewController.h"
#import "DCChatViewController.h"
#import "DCServerCommunicator.h"
#import "DCGuild.h"
#import "DCChannel.h"

@interface DCChannelListViewController ()
@property int selectedChannelIndex;
@property DCChannel* selectedChannel;
@end

@implementation DCChannelListViewController


- (void)viewDidLoad{
	[super viewDidLoad];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageAck) name:@"MESSAGE ACK" object:nil];
}


-(void)viewWillAppear:(BOOL)animated{
	[self.navigationItem setTitle:self.selectedGuild.name];
}


- (void)handleMessageAck {
	[self.tableView reloadData];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	
	//static NSString *guildCellIdentifier = @"Channel Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Channel Cell"];
	
	DCChannel* channelAtRowIndex = [self.selectedGuild.channels objectAtIndex:indexPath.row];
	if(channelAtRowIndex.unread)
		[cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
	else
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	[cell.textLabel setText:channelAtRowIndex.name];
	
	return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return self.selectedGuild.channels.count;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	DCServerCommunicator.sharedInstance.selectedChannel = [self.selectedGuild.channels objectAtIndex:indexPath.row];
	
	[DCServerCommunicator.sharedInstance.selectedChannel ackMessage:DCServerCommunicator.sharedInstance.selectedChannel.lastMessageId];
	
	[DCServerCommunicator.sharedInstance.selectedChannel checkIfRead];
	
	[[self.tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	[self performSegueWithIdentifier:@"Channels to Chat" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Channels to Chat"]){
		
		DCChatViewController *chatViewController = [segue destinationViewController];
		
		if ([chatViewController isKindOfClass:DCChatViewController.class]){
			
			dispatch_async(dispatch_get_main_queue(), ^{
				chatViewController.messages = NSMutableArray.new;
				[chatViewController getMessages:50 beforeMessage:nil];
			});
		}
	}
}

@end
