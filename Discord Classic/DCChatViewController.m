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
#import "DCImageViewController.h"
#import "TRMalleableFrameView.h"

@interface DCChatViewController()
@property bool viewingPresentTime;
@property int numberOfMessagesLoaded;
@property UIImage* selectedImage;
@end

@implementation DCChatViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleMessageCreate:) name:@"MESSAGE CREATE" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reloadData) name:@"RELOAD CHAT DATA" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleReady) name:@"READY" object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)handleReady {
	if(DCServerCommunicator.sharedInstance.selectedChannel)
		self.messages = NSMutableArray.new;
	
	[self getMessages:50 beforeMessage:nil];
	
	[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:NO];
}

- (void)reloadData {
	[self.chatTableView reloadData];
}

- (void)handleMessageCreate:(NSNotification*)notification {
  DCMessage* newMessage = [DCTools convertJsonMessage:notification.userInfo];
	
	[self.messages addObject:newMessage];
	[self.chatTableView reloadData];
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:NO];
}

- (void)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message{
	NSArray* newMessages = [DCServerCommunicator.sharedInstance.selectedChannel getMessages:numberOfMessages beforeMessage:message];
	
	if(newMessages){
		NSRange range = NSMakeRange(0, [newMessages count]);
		NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
		[self.messages insertObjects:newMessages atIndexes:indexSet];
		
		[self.chatTableView reloadData];
		
		int scrollOffset = -self.chatTableView.height;
		for(DCMessage* newMessage in newMessages)
			scrollOffset += newMessage.contentHeight + newMessage.embeddedImageCount * 220;
		
		[self.chatTableView setContentOffset:CGPointMake(0, scrollOffset) animated:NO];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	//static NSString *guildCellIdentifier = @"Channel Cell";
	
	[tableView registerNib:[UINib nibWithNibName:@"DCChatTableCell" bundle:nil] forCellReuseIdentifier:@"Message Cell"];
	DCChatTableCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Message Cell"];
	
	DCMessage* messageAtRowIndex = [self.messages objectAtIndex:indexPath.row];
	
	[cell.authorLabel setText:messageAtRowIndex.author.username];
	
	[cell.contentView setText:messageAtRowIndex.content];
	
	[cell.profileImage setImage:messageAtRowIndex.author.profileImage];
	
	for (UIView *subView in cell.subviews) {
		if ([subView isKindOfClass:[UIImageView class]]) {
			[subView removeFromSuperview];
		}
	}
	
	[cell.contentView setScrollEnabled:NO];
	
	[cell.contentView setFrame:CGRectMake(47, 17, UIScreen.mainScreen.bounds.size.width-47,[cell.contentView sizeThatFits:CGSizeMake(cell.contentView.width, MAXFLOAT)].height)];
	
	int imageViewOffset = cell.contentView.height + 37;
	
	for(UIImage* image in messageAtRowIndex.embeddedImages){
		UIImageView* imageView = UIImageView.new;
		[imageView setFrame:CGRectMake(11, imageViewOffset, self.chatTableView.width - 22, 200)];
		[imageView setImage:image];
		imageViewOffset += 210;
		
		[imageView setContentMode: UIViewContentModeScaleAspectFit];
		
		UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedImage:)];
		singleTap.numberOfTapsRequired = 1;
    imageView.userInteractionEnabled = YES;
		[imageView addGestureRecognizer:singleTap];
		
		[cell addSubview:imageView];
	}
	return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	DCMessage* messageAtRowIndex = [self.messages objectAtIndex:indexPath.row];
	
	return messageAtRowIndex.contentHeight + messageAtRowIndex.embeddedImageCount * 220;
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
	[DCServerCommunicator.sharedInstance.selectedChannel sendMessage:self.inputField.text];
	
	[self.inputField setText:@""];
	
	if(self.viewingPresentTime)
		[self.chatTableView setContentOffset:CGPointMake(0, self.chatTableView.contentSize.height - self.chatTableView.frame.size.height) animated:YES];
}

- (void)tappedImage:(UITapGestureRecognizer *)sender {
	self.selectedImage = ((UIImageView*)sender.view).image;
	[self performSegueWithIdentifier:@"Chat to Gallery" sender:self];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
	if ([segue.identifier isEqualToString:@"Chat to Gallery"]){
		
		DCImageViewController	*imageViewController = [segue destinationViewController];
		
		if ([imageViewController isKindOfClass:DCImageViewController.class]){
			dispatch_async(dispatch_get_main_queue(), ^{
				[imageViewController.imageView setImage:self.selectedImage];
			});
		}
	}
}


- (IBAction)chooseImage:(id)sender {
	UIImagePickerController *picker = UIImagePickerController.new;
	
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	
	[picker setDelegate:self];
	
	[self presentModalViewController:picker animated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	
	[picker dismissModalViewControllerAnimated:YES];
	
	UIImage* originalImage = nil;
	originalImage = [info objectForKey:UIImagePickerControllerEditedImage];
	
	if(originalImage==nil)
		originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
	
	if(originalImage==nil)
		originalImage = [info objectForKey:UIImagePickerControllerCropRect];
	
	[DCServerCommunicator.sharedInstance.selectedChannel sendImage:originalImage];
}
@end