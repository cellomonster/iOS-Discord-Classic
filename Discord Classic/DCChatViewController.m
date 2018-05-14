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
	
	NSString* formattedChannelName;
	if(self.selectedChannel.type == 0)
		formattedChannelName = [@"#" stringByAppendingString:self.selectedChannel.name];
	else if(self.selectedChannel.type == 1)
		formattedChannelName = [@"@" stringByAppendingString:self.selectedChannel.name];
	else
		formattedChannelName = self.selectedChannel.name;
	
	[self.navigationItem setTitle:formattedChannelName];
}


- (void)viewWillDisappear:(BOOL)animated{
	DCServerCommunicator.sharedInstance.selectedChannel = nil;
}


- (void)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message{
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		//Generate URL from args
		NSMutableString* getChannelAddress = [[NSString stringWithFormat:
																					 @"https://discordapp.com/api/channels/%@%@",
																					 self.selectedChannel.snowflake,
																					 @"/messages?"] mutableCopy];
		
		if(numberOfMessages)
			[getChannelAddress appendString:[NSString stringWithFormat:@"limit=%i", numberOfMessages]];
		if(numberOfMessages && message)
			[getChannelAddress appendString:@"&"];
		if(message)
			[getChannelAddress appendString:[NSString stringWithFormat:@"before=%@", message.snowflake]];
		
		NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:getChannelAddress]
																															cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
																													timeoutInterval:60.0];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		NSError *error;
		NSHTTPURLResponse *responseCode;
		
		NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest
																																returningResponse:&responseCode
																																						error:&error] withError:error];

		
		NSArray* parsedResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];;
		
		if(parsedResponse){
			
			int scrollDownHeight = 0;
			
			for(NSDictionary* jsonMessage in parsedResponse){
							
				DCMessage* newMessage = [self convertJsonMessage:jsonMessage];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.messages insertObject:newMessage atIndex:0];
				});
				
				CGSize authorNameSize = [newMessage.authorName sizeWithFont:[UIFont boldSystemFontOfSize:15]
																												 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																														 lineBreakMode:UILineBreakModeWordWrap];
				CGSize contentSize = [newMessage.content sizeWithFont:[UIFont systemFontOfSize:14]
																									 constrainedToSize:CGSizeMake(self.chatTableView.width - 22, MAXFLOAT)
																											 lineBreakMode:UILineBreakModeWordWrap];
				if(newMessage.hasEmbededImage)
					scrollDownHeight+= 200;
				scrollDownHeight += authorNameSize.height + contentSize.height + 11;
			}
			
			if(!self.viewingPresentTime)
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.chatTableView setContentOffset:CGPointMake(0, scrollDownHeight) animated:NO];
					[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentOffset.y - 50) animated:YES];
				});
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.numberOfMessagesLoaded = 50;
			[self.chatTableView reloadData];
			
			if(self.viewingPresentTime)
				[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:NO];
		});
	});
}


- (DCMessage*)convertJsonMessage:(NSDictionary*)jsonMessage{
	DCMessage* newMessage = DCMessage.new;
	newMessage.authorName = [jsonMessage valueForKeyPath:@"author.username"];
	newMessage.content = [jsonMessage valueForKey:@"content"];
	newMessage.snowflake = [jsonMessage valueForKey:@"id"];
	
	NSArray* embeds = [jsonMessage objectForKey:@"embeds"];
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
	
	NSArray* attachments = [jsonMessage objectForKey:@"attachments"];
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
	
	return newMessage;
}


- (void)handleReady {
	if(self.selectedChannel)
        self.messages = NSMutableArray.new;
		[self getMessages:50 beforeMessage:nil];
}

- (void)handleMessageCreate:(NSNotification*)notification {
  DCMessage* newMessage = [self convertJsonMessage:notification.userInfo];
	
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
	if(self.messages.count > 0 && scrollView.contentOffset.y == 0)
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