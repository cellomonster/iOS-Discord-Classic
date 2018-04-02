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

@interface DCGuildListViewController ()
@property DCGuild* selectedGuild;
@end

@implementation DCGuildListViewController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Guild Cell"];
	
	DCGuild* guildAtRowIndex = [DCServerCommunicator.sharedInstance.guilds objectAtIndex:indexPath.row];
	
	if(!guildAtRowIndex.read)
		[cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
	else
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	[cell.textLabel setText:guildAtRowIndex.name];
	
	[cell.imageView setImage:guildAtRowIndex.icon];
	
	return cell;
}


-(void)viewWillAppear:(BOOL)animated{
	[self.tableView reloadData];
}


- (void)viewDidLoad{
	[super viewDidLoad];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady:) name:@"READY" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageAck:) name:@"MESSAGE ACK" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady:) name:@"RELOAD GUILD LIST" object:nil];
	
	if(!DCServerCommunicator.sharedInstance.token.length)
		[self performSegueWithIdentifier:@"to Settings" sender:self];
}

- (void)handleReady:(NSNotification*)notification {
	//Refresh tableView data on READY notification
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
	//We only have as many items as we are members of guilds
	return DCServerCommunicator.sharedInstance.guilds.count;
}

/*-(void)viewWillAppear:(BOOL)animated{
 for(int i = 0; i < DCServerCommunicator.sharedInstance.guilds.count; i++){
 
 DCGuild* guildAtIndex = [DCServerCommunicator.sharedInstance.guilds objectAtIndex:i];
 NSIndexPath* indexPath = [NSIndexPath indexPathForRow:i inSection:0];
 UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
 
 NSString* iconURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/icons/%@/%@",
 guildAtIndex.snowflake, guildAtIndex.iconHash];
 
 [DCWebImageOperations processImageDataWithURLString:iconURL andBlock:^(NSData *imageData) {
 [cell.imageView setImage:[UIImage imageWithData:imageData]];
 [self.tableView reloadData];
 }];
 }
 }*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	[self setSelectedGuild:[DCServerCommunicator.sharedInstance.guilds objectAtIndex:indexPath.row]];
	[self performSegueWithIdentifier:@"Guilds to Channels" sender:self];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Guilds to Channels"]){
		
		DCChannelListViewController *channelListViewController = [segue destinationViewController];
		
		if ([channelListViewController isKindOfClass:DCChannelListViewController.class])
			[channelListViewController setSelectedGuild:self.selectedGuild];
	}
}

@end