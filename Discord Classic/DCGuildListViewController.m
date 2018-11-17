//
//  DCGuildViewController.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/4/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCGuildListViewController.h"
#import "DCChannelListViewController.h"
#import "DCServerCommunicator.h"
#import "DCGuild.h"
#import "DCTools.h"

@implementation DCGuildListViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	//Go to settings if no token is set
	if(!DCServerCommunicator.sharedInstance.token)
		[self performSegueWithIdentifier:@"to Settings" sender:self];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"READY" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"MESSAGE ACK" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"RELOAD GUILD LIST" object:nil];
}


- (void)handleReady {
	//Refresh tableView data on READY notification
  [self.tableView reloadData];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Guild Cell"];
	
	DCGuild* guildAtRowIndex = [DCServerCommunicator.sharedInstance.guilds objectAtIndex:indexPath.row];
	
	if(guildAtRowIndex.unread)
		[cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
	else
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	[cell.textLabel setText:guildAtRowIndex.name];
	
	[cell.imageView setImage:guildAtRowIndex.icon];
	
	return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return DCServerCommunicator.sharedInstance.guilds.count;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	if([DCServerCommunicator.sharedInstance.guilds objectAtIndex:indexPath.row] != DCServerCommunicator.sharedInstance.selectedGuild){
		DCServerCommunicator.sharedInstance.loadedUsers = NSMutableDictionary.new;
		DCServerCommunicator.sharedInstance.selectedGuild = [DCServerCommunicator.sharedInstance.guilds objectAtIndex:indexPath.row];
	}
	[self performSegueWithIdentifier:@"Guilds to Channels" sender:self];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Guilds to Channels"]){
		
		DCChannelListViewController *channelListViewController = [segue destinationViewController];
		
		if ([channelListViewController isKindOfClass:DCChannelListViewController.class])
			channelListViewController.selectedGuild = DCServerCommunicator.sharedInstance.selectedGuild;
	}
}

@end