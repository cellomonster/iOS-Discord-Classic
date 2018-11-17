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
#import "DCUser.h"

@interface DCChatViewController()
@property bool viewingPresentTime;
@property int numberOfMessagesLoaded;
@end

@implementation DCChatViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageCreate:) name:@"MESSAGE CREATE" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"READY" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
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
		NSMutableString* getChannelAddress = [[NSString stringWithFormat: @"https://discordapp.com/api/channels/%@%@", self.selectedChannel.snowflake, @"/messages?"] mutableCopy];
		
		if(numberOfMessages)
			[getChannelAddress appendString:[NSString stringWithFormat:@"limit=%i", numberOfMessages]];
		if(numberOfMessages && message)
			[getChannelAddress appendString:@"&"];
		if(message)
			[getChannelAddress appendString:[NSString stringWithFormat:@"before=%@", message.snowflake]];
		
		NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:getChannelAddress] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
		
		[urlRequest addValue:DCServerCommunicator.sharedInstance.token forHTTPHeaderField:@"Authorization"];
		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		
		NSError *error;
		NSHTTPURLResponse *responseCode;
		
		NSData *response = [DCTools checkData:[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&responseCode error:&error] withError:error];

		
		NSArray* parsedResponse = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
		
		if(parsedResponse.count > 0){
			
			int scrollDownHeight = 0;
			
			for(NSDictionary* jsonMessage in parsedResponse){
							
				DCMessage* newMessage = [self convertJsonMessage:jsonMessage];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.messages insertObject:newMessage atIndex:0];
				});
				
				CGSize authorNameSize = [newMessage.author.username sizeWithFont:[UIFont boldSystemFontOfSize:15] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
				CGSize contentSize = [newMessage.content sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
				for(int i = 0; i < newMessage.embeddedImageCount; i++) scrollDownHeight+= 210;
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
	if(![DCServerCommunicator.sharedInstance.loadedUsers objectForKey:[jsonMessage valueForKeyPath:@"author.id"]]){
		
		NSLog(@"user for message does not exist, creating one");
		DCUser* newUser = DCUser.new;
		newUser.username = [jsonMessage valueForKeyPath:@"author.username"];
		newUser.snowflake = [jsonMessage valueForKeyPath:@"author.id"];
		
		NSString* avatarURL = [NSString stringWithFormat:@"https://cdn.discordapp.com/avatars/%@/%@.png", newUser.snowflake, [jsonMessage valueForKeyPath:@"author.avatar"]];
		
		NSLog(@"%@", avatarURL);
		
		[DCTools processImageDataWithURLString:avatarURL andBlock:^(NSData *imageData){
			UIImage *retrievedImage = [UIImage imageWithData:imageData];
			
			NSLog(@"loaded pfp!");
			
			if(retrievedImage != nil){
				newUser.profileImage = retrievedImage;
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.chatTableView reloadData];
				});
			}
			
		}];
		
		[DCServerCommunicator.sharedInstance.loadedUsers setValue:newUser forKey:newUser.snowflake];
	}
	
	newMessage.author = [DCServerCommunicator.sharedInstance.loadedUsers valueForKey:[jsonMessage valueForKeyPath:@"author.id"]];
	
	newMessage.content = [jsonMessage valueForKey:@"content"];
	newMessage.snowflake = [jsonMessage valueForKey:@"id"];
	newMessage.embeddedImages = NSMutableArray.new;
	newMessage.embeddedImageCount = 0;
	
	NSArray* embeds = [jsonMessage objectForKey:@"embeds"];
	
	if(embeds)
		for(NSDictionary* embed in embeds){
			NSString* embedType = [embed valueForKey:@"type"];
			if([embedType isEqualToString:@"image"]){
				newMessage.embeddedImageCount++;
				
				[DCTools processImageDataWithURLString:[embed valueForKeyPath:@"thumbnail.url"] andBlock:^(NSData *imageData){
					UIImage *retrievedImage = [UIImage imageWithData:imageData];
					
					if(retrievedImage != nil){
						[newMessage.embeddedImages addObject:retrievedImage];
						dispatch_async(dispatch_get_main_queue(), ^{
							[self.chatTableView reloadData];
						});
					}
					
				}];
			}
		}
	
	NSArray* attachments = [jsonMessage objectForKey:@"attachments"];
	if(attachments)
		for(NSDictionary* attachment in attachments){
			newMessage.embeddedImageCount++;
			
			[DCTools processImageDataWithURLString:[attachment valueForKey:@"url"] andBlock:^(NSData *imageData){
				UIImage *retrievedImage = [UIImage imageWithData:imageData];
				
				if(retrievedImage != nil){
					[newMessage.embeddedImages addObject:retrievedImage];
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.chatTableView reloadData];
					});
				}
			}];
		}
	
	return newMessage;
}

- (void)handleReady {
	if(self.selectedChannel) self.messages = NSMutableArray.new;
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
	
	[cell.authorLabel setText:messageAtRowIndex.author.username];
	
	[cell.contentLabel setText:messageAtRowIndex.content];
	
	[cell.profileImage setImage:messageAtRowIndex.author.profileImage];
	
	CGRect contentLabelBounds = cell.contentLabel.bounds;
	contentLabelBounds.size.height = CGFLOAT_MAX;
	CGRect minimumTextRect = [cell.contentLabel textRectForBounds:contentLabelBounds limitedToNumberOfLines:0];
	
	CGFloat contentLabelHeightDelta = minimumTextRect.size.height - cell.contentLabel.height;
	CGRect contentFrame = cell.contentLabel.frame;
	contentFrame.size.height += contentLabelHeightDelta;
	cell.contentLabel.frame = contentFrame;
	
	for (UIView *subView in cell.subviews) {
		if ([subView isKindOfClass:[UIImageView class]]) {
			[subView removeFromSuperview];
		}
	}
	
	CGSize authorNameSize = [messageAtRowIndex.author.username sizeWithFont:[UIFont boldSystemFontOfSize:15] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	CGSize contentSize = [messageAtRowIndex.content sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	
	int imageViewOffset = authorNameSize.height + contentSize.height + 20;
	
	for(UIImage* image in messageAtRowIndex.embeddedImages){
		UIImageView* imageView = UIImageView.new;
		[imageView setFrame:CGRectMake(11, imageViewOffset, self.chatTableView.width - 22, 200)];
		[imageView setImage:image];
		imageViewOffset += 210;
		
		[imageView setContentMode: UIViewContentModeScaleAspectFit];
		
		[cell addSubview:imageView];
	}
	return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	DCMessage* messageAtRowIndex = [self.messages objectAtIndex:indexPath.row];
	
	CGSize authorNameSize = [messageAtRowIndex.author.username sizeWithFont:[UIFont boldSystemFontOfSize:15] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	CGSize contentSize = [messageAtRowIndex.content sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(self.chatTableView.width - 69, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
	return authorNameSize.height + contentSize.height + 11 + messageAtRowIndex.embeddedImageCount * 220;
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
	[UIView commitAnimations];
}


- (IBAction)hideKeyboard:(id)sender {
	[self.inputField resignFirstResponder];
}


- (IBAction)sendMessage:(id)sender {
	[self.selectedChannel sendMessage:self.inputField.text];
	
	[self.inputField setText:@""];
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:YES];
}

//- (IBAction)chooseImage:(id)sender {
//	UIImagePickerController *picker = UIImagePickerController.new;
//	
//	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//	
//	picker.allowsEditing = YES;
//	
//	[picker setDelegate:self];
//	
//	[self presentModalViewController:picker animated:YES];
//}
//
//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
//	
//	[picker dismissModalViewControllerAnimated:YES];
//	
//	UIImage* originalImage = nil;
//	originalImage = [info objectForKey:UIImagePickerControllerEditedImage];
//	
//	if(originalImage==nil)
//		originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
//	
//	if(originalImage==nil)
//		originalImage = [info objectForKey:UIImagePickerControllerCropRect];
//	
//	[DCServerCommunicator.sharedInstance sendImage:originalImage inChannel:self.selectedChannel];
//	
//	if(self.viewingPresentTime)
//		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:YES];
//}
@end