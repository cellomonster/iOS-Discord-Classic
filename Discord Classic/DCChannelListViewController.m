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
@property (nonatomic)  DCGuild* selectedGuild;
@property int selectedChannelIndex;
@property DCChannel* selectedChannel;
@end

@implementation DCChannelListViewController


- (void)viewDidLoad{
	[super viewDidLoad];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageAck:) name:@"MESSAGE ACK" object:nil];
	[self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Background.tiff"]]];
}


-(void)viewWillAppear:(BOOL)animated{
	[self.navigationItem setTitle:self.selectedGuild.name];
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


-(void)setSelectedGuild:(DCGuild*)selectedGuild{
	//self.selectedGuild causes crash and im not smart enough to know why
	_selectedGuild = selectedGuild;
	[self.tableView reloadData];
}


- (void)handleMessageAck:(NSNotification*)notification {
	[self.tableView reloadData];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return self.selectedGuild.channels.count;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	[self setSelectedChannel:[self.selectedGuild.channels objectAtIndex:indexPath.row]];
	
	self.selectedChannel.lastReadMessageId = self.selectedChannel.lastMessageId;
	
	[DCServerCommunicator.sharedInstance ackMessage:self.selectedChannel.lastMessageId inChannel:self.selectedChannel];
	
	[self.selectedChannel checkIfRead];
	
	UITableViewCell* cellAtIndex = [self.tableView cellForRowAtIndexPath:indexPath];
	
	[cellAtIndex setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	NSLog(@"Selected channel: %@", self.selectedChannel);
	[self performSegueWithIdentifier:@"Channels to Chat" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Channels to Chat"]){
		
		DCChatViewController *chatViewController = [segue destinationViewController];
		
		if ([chatViewController isKindOfClass:DCChatViewController.class]){
			[chatViewController setSelectedChannel:self.selectedChannel];
			[DCServerCommunicator.sharedInstance setSelectedChannel:self.selectedChannel];
			dispatch_async(dispatch_get_main_queue(), ^{
				[chatViewController getMessages];
			});
		}
	}
}

@end
