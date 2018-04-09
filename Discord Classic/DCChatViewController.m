//
//  DCChatViewController.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/6/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCChatViewController.h"
#import "DCServerCommunicator.h"
#import "TRMalleableFrameView.h"
#import "DCMessage.h"
#import "DCTools.h"
#import "DCChatTableCell.h"

@interface DCChatViewController()
@property NSArray* jsonMessages;
@end

@implementation DCChatViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageCreate:) name:@"MESSAGE CREATE" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"READY" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self
																				 selector:@selector(keyboardWillShow:)
																						 name:UIKeyboardWillShowNotification
																					 object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self
																				 selector:@selector(keyboardWillHide:)
																						 name:UIKeyboardWillHideNotification
																					 object:nil];
	
	[self.chatTableView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Background.tiff"]]];
}


-(void)viewWillAppear:(BOOL)animated{
	NSString* channelNameWithPound;
	if(self.selectedChannel.type == 0)
		channelNameWithPound = [@"#" stringByAppendingString:self.selectedChannel.name];
	else if(self.selectedChannel.type == 1)
		channelNameWithPound = [@"@" stringByAppendingString:self.selectedChannel.name];
	else
		channelNameWithPound = self.selectedChannel.name;
	[self.navigationItem setTitle:channelNameWithPound];
}


- (void)viewWillDisappear:(BOOL)animated{
	[DCServerCommunicator.sharedInstance setSelectedChannel:nil];
}


- (void)getMessages{
	self.messages = NSMutableArray.new;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSURL* getChannelURL = [NSURL URLWithString:
														[NSString stringWithFormat:@"%@%@%@",
														 @"https://discordapp.com/api/channels/",
														 self.selectedChannel.snowflake,
														 @"/messages"]];
		
		NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:getChannelURL
																															cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
																													timeoutInterval:60.0];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		NSError *error;
		NSHTTPURLResponse *responseCode;
		
		NSData *response = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error];
		
		id parsedResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
		
		if([parsedResponse isKindOfClass:NSArray.class]){
			self.jsonMessages = parsedResponse;
			
			for(NSDictionary* message in [self.jsonMessages reverseObjectEnumerator]){
				DCMessage* newMessage = DCMessage.new;
				newMessage.authorName = [message valueForKeyPath:@"author.username"];
				newMessage.content = [message valueForKey:@"content"];
				
				NSArray* embeds = [message objectForKey:@"embeds"];
				if(embeds)
					for(NSDictionary* embed in embeds){
						NSString* embedType = [embed valueForKey:@"type"];
						if([embedType isEqualToString:@"image"]){
							newMessage.hasEmbededImage = true;
							NSString* embededImageAddress = [embed valueForKeyPath:@"thumbnail.url"];
							
							[DCTools processImageDataWithURLString:embededImageAddress andBlock:^(NSData *imageData){
								newMessage.embededImage = [UIImage imageWithData:imageData];
								dispatch_async(dispatch_get_main_queue(), ^{
									[self.chatTableView reloadData];
								});
							}];
						}
					}
				
				NSArray* attachments = [message objectForKey:@"attachments"];
				if(attachments)
					for(NSDictionary* attachment in attachments){
						NSString* embededImageAddress = [attachment valueForKey:@"url"];
						newMessage.hasEmbededImage = true;
						[DCTools processImageDataWithURLString:embededImageAddress andBlock:^(NSData *imageData){
							newMessage.embededImage = [UIImage imageWithData:imageData];
							dispatch_async(dispatch_get_main_queue(), ^{
								[self.chatTableView reloadData];
							});
						}];
					}
				
				[self.messages addObject:newMessage];
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.chatTableView reloadData];
			
			CGPoint offset = CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height);
			[self.chatTableView setContentOffset:offset animated:NO];
		});
	});
}


- (void)handleReady {
	if(self.selectedChannel)
		[self getMessages];
}


- (void)handleMessageCreate:(NSNotification*)notification {
	
  DCMessage* newMessage = DCMessage.new;
	newMessage.authorName = [notification.userInfo valueForKeyPath:@"author.username"];
	newMessage.content = [notification.userInfo valueForKey:@"content"];
	NSLog(@"%@", notification.userInfo);
	NSArray* embeds = [notification.userInfo objectForKey:@"embeds"];
	if(embeds)
		for(NSDictionary* embed in embeds){
			NSString* embedType = [embed valueForKey:@"type"];
			if([embedType isEqualToString:@"image"]){
				newMessage.hasEmbededImage = true;
				NSString* embededImageAddress = [embed valueForKeyPath:@"thumbnail.url"];
				
				[DCTools processImageDataWithURLString:embededImageAddress andBlock:^(NSData *imageData){
					newMessage.embededImage = [UIImage imageWithData:imageData];
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.chatTableView reloadData];
					});
				}];
			}
		}
	
	NSArray* attachments = [notification.userInfo objectForKey:@"attachments"];
	if(attachments)
		for(NSDictionary* attachment in attachments){
			NSString* embededImageAddress = [attachment valueForKey:@"url"];
			newMessage.hasEmbededImage = true;
			[DCTools processImageDataWithURLString:embededImageAddress andBlock:^(NSData *imageData){
				newMessage.embededImage = [UIImage imageWithData:imageData];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.chatTableView reloadData];
				});
			}];
		}

	
	[self.messages addObject:newMessage];
	[self.chatTableView reloadData];
	
	CGPoint offset = CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height);
	[self.chatTableView setContentOffset:offset animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	//static NSString *guildCellIdentifier = @"Channel Cell";
	
	[tableView registerNib:[UINib nibWithNibName:@"DCChatTableCell" bundle:nil] forCellReuseIdentifier:@"Message Cell"];
	DCChatTableCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Message Cell"];
	
	DCMessage* messageAtRowIndex = [self.messages objectAtIndex:indexPath.row];
	
	[cell.authorLabel setText:messageAtRowIndex.authorName];
	
	[cell.contentLabel setText:messageAtRowIndex.content];
	
	CGRect contentLabelBounds = cell.contentLabel.bounds;
	contentLabelBounds.size.height = CGFLOAT_MAX;
	CGRect minimumTextRect = [cell.contentLabel textRectForBounds:contentLabelBounds limitedToNumberOfLines:0];
	
	CGFloat contentLabelHeightDelta = minimumTextRect.size.height - cell.contentLabel.height;
	CGRect contentFrame = cell.contentLabel.frame;
	contentFrame.size.height += contentLabelHeightDelta;
	cell.contentLabel.frame = contentFrame;
	
	[cell.embededImageView setImage:messageAtRowIndex.embededImage];
	cell.embededImageView.contentMode = UIViewContentModeScaleAspectFit;
	return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	DCMessage* messageAtRowIndex = [self.messages objectAtIndex:indexPath.row];
	
	CGSize authorNameSize = [messageAtRowIndex.authorName sizeWithFont:[UIFont boldSystemFontOfSize:15]
																									 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																											 lineBreakMode:UILineBreakModeWordWrap];
	CGSize contentSize = [messageAtRowIndex.content sizeWithFont:[UIFont systemFontOfSize:14]
																						 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																								 lineBreakMode:UILineBreakModeWordWrap];
	
	if(messageAtRowIndex.hasEmbededImage)
		return authorNameSize.height + contentSize.height + 211;
	return authorNameSize.height + contentSize.height + 11;
}


-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return self.messages.count;
}

#pragma mark - Table view delegate


- (void)keyboardWillShow:(NSNotification *)notification {
	
	//thx to Pierre Legrain
	//http://pyl.io/2015/08/17/animating-in-sync-with-ios-keyboard/
	
	int keyboardHeight = [[notification.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height;
	float keyboardAnimationDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	int keyboardAnimationCurve = [[notification.userInfo objectForKey: UIKeyboardAnimationCurveUserInfoKey] integerValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:keyboardAnimationDuration];
	[UIView setAnimationCurve:keyboardAnimationCurve];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[self.chatTableView setHeight:self.view.height - keyboardHeight - self.toolbar.height];
	[self.toolbar setY:self.view.height - keyboardHeight - self.toolbar.height];
	[self.inputField setWidth:self.toolbar.width - 110];
	[UIView commitAnimations];
	
	CGPoint offset = CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height);
	[self.chatTableView setContentOffset:offset animated:NO];
}


- (void)keyboardWillHide:(NSNotification *)notification {
	
	float keyboardAnimationDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	int keyboardAnimationCurve = [[notification.userInfo objectForKey: UIKeyboardAnimationCurveUserInfoKey] integerValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:keyboardAnimationDuration];
	[UIView setAnimationCurve:keyboardAnimationCurve];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[self.chatTableView setHeight:self.view.height - self.toolbar.height];
	[self.toolbar setY:self.view.height - self.toolbar.height];
	[self.inputField setWidth:self.toolbar.width - 12];
	[UIView commitAnimations];
}


- (IBAction)hideKeyboard:(id)sender {
	[self.inputField resignFirstResponder];
}


- (IBAction)sendMessage:(id)sender {
	[DCServerCommunicator.sharedInstance sendMessage:self.inputField.text inChannel:self.selectedChannel];
	
	[self.inputField setText:@""];
	
	CGPoint offset = CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height);
	[self.chatTableView setContentOffset:offset animated:YES];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end