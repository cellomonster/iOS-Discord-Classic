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
@property bool viewingPresentTime;
@property int numberOfMessagesLoaded;
@end

@implementation DCChatViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	[self.chatTableView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Background.tiff"]]];
	
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
}


-(void)viewWillAppear:(BOOL)animated{
	self.messages = NSMutableArray.new;
	self.viewingPresentTime = true;
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
	DCServerCommunicator.sharedInstance.selectedChannel = nil;
}


- (void)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message{
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSURL* getChannelURL = [NSURL URLWithString:
														[NSString stringWithFormat:@"%@%@%@",
														 @"https://discordapp.com/api/channels/",
														 self.selectedChannel.snowflake,
														 @"/messages"]];
		
		if(message)
			getChannelURL = [NSURL URLWithString:
											 [NSString stringWithFormat:@"%@%@%@%@",
												@"https://discordapp.com/api/channels/",
												self.selectedChannel.snowflake,
												@"/messages?before=",message.snowflake]];
		
		NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:getChannelURL
																															cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
																													timeoutInterval:60.0];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		NSError *error;
		NSHTTPURLResponse *responseCode;
		
		NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest
																																returningResponse:&responseCode
																																						error:&error] withError:error];

		
		id parsedResponse;
		
		if(response)
			parsedResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
		
#warning TODO: consolidate this attachment handling boiler code
		if([parsedResponse isKindOfClass:NSArray.class]){
			self.jsonMessages = parsedResponse;
			
			int scrollDown = 0;
			
			for(NSDictionary* message in self.jsonMessages){
				DCMessage* newMessage = DCMessage.new;
				newMessage.authorName = [message valueForKeyPath:@"author.username"];
				newMessage.content = [message valueForKey:@"content"];
				newMessage.snowflake = [message valueForKey:@"id"];
				NSLog(@"new msg %@ %@", newMessage.snowflake, newMessage.content);
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
				
				CGSize authorNameSize = [newMessage.authorName sizeWithFont:[UIFont boldSystemFontOfSize:15]
																												 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																														 lineBreakMode:UILineBreakModeWordWrap];
				CGSize contentSize = [newMessage.content sizeWithFont:[UIFont systemFontOfSize:14]
																									 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																											 lineBreakMode:UILineBreakModeWordWrap];
				
				if(newMessage.hasEmbededImage)
					scrollDown+= 200;
				scrollDown += authorNameSize.height + contentSize.height + 11;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.messages insertObject:newMessage atIndex:0];
				});
			}
			if(!self.viewingPresentTime)
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.chatTableView setContentOffset:CGPointMake(0, scrollDown) animated:NO];
					[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentOffset.y - 50) animated:YES];
				});
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			
			self.numberOfMessagesLoaded = 50;
			[self.chatTableView reloadData];
			
//			if(self.viewingPresentTime)
//				[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:NO];
		});
	});
}


- (void)handleReady {
	if(self.selectedChannel)
		[self getMessages:50 beforeMessage:nil];
}

#warning TODO: consolidate this attachment handling boiler code
- (void)handleMessageCreate:(NSNotification*)notification {
	
  DCMessage* newMessage = DCMessage.new;
	newMessage.authorName = [notification.userInfo valueForKeyPath:@"author.username"];
	newMessage.content = [notification.userInfo valueForKey:@"content"];
	
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
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:YES];
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
		return authorNameSize.height + contentSize.height + 220;
	return authorNameSize.height + contentSize.height + 11;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	if(scrollView.contentOffset.y == 0)
		[self getMessages:50 beforeMessage:[self.messages objectAtIndex:0]];
	
	self.viewingPresentTime = (scrollView.contentOffset.y == scrollView.contentSize.height - scrollView.height);
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return self.messages.count;
}


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
	
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:NO];
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
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:YES];
}

@end