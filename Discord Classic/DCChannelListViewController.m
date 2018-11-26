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
#import "TRMalleableFrameView.h"

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
	[DCServerCommunicator.sharedInstance setSelectedChannel:nil];
}


- (void)handleMessageAck {
	[self.tableView reloadData];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Channel Cell"];
	
	//Show blue indicator if channel contains any unread messages
	DCChannel* channelAtRowIndex = [self.selectedGuild.channels objectAtIndex:indexPath.row];
	if(channelAtRowIndex.unread)
		[cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
	else
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	//Channel name
	[cell.textLabel setText:channelAtRowIndex.name];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	DCServerCommunicator.sharedInstance.selectedChannel = [self.selectedGuild.channels objectAtIndex:indexPath.row];
	
	//Mark channel messages as read and refresh the channel object accordingly
	[DCServerCommunicator.sharedInstance.selectedChannel ackMessage:DCServerCommunicator.sharedInstance.selectedChannel.lastMessageId];
	[DCServerCommunicator.sharedInstance.selectedChannel checkIfRead];
	
	//Remove the blue indicator since the channel has been read
	[[self.tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	//Transition to chat view
	[self performSegueWithIdentifier:@"Channels to Chat" sender:self];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Channels to Chat"]){
		DCChatViewController *chatViewController = [segue destinationViewController];
		
		if ([chatViewController isKindOfClass:DCChatViewController.class]){
			
			//Initialize messages
			chatViewController.messages = NSMutableArray.new;
			
			//Add a '#' if appropriate to the chanel name in the navigation bar
			NSString* formattedChannelName;
			if(DCServerCommunicator.sharedInstance.selectedChannel.type == 0)
				formattedChannelName = [@"#" stringByAppendingString:DCServerCommunicator.sharedInstance.selectedChannel.name];
			else
				formattedChannelName = DCServerCommunicator.sharedInstance.selectedChannel.name;
			[chatViewController.navigationItem setTitle:formattedChannelName];
			
			//Populate the message view with the last 50 messages
			[chatViewController getMessages:50 beforeMessage:nil];
			
			//Chat view is watching the present conversation (auto scroll with new messages)
			[chatViewController setViewingPresentTime:true];
		}
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 1;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return self.selectedGuild.channels.count;}
@end
