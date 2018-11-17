//
//  DCChatViewController.h
//  Discord Classic
//
//  Created by Julian Triveri on 3/6/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DCChannel.h"
#import "DCMessage.h"

@interface DCChatViewController : UIViewController <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate>
- (void)getMessages:(int)numberOfMessages beforeMessage:(DCMessage*)message;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UITableView *chatTableView;
@property (weak, nonatomic) IBOutlet UITextField *inputField;

@property NSMutableArray* messages;
@end
