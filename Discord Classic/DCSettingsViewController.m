//
//  DCSettingsViewController.m
//  Discord Classic
//
//  Created by Trevir on 3/18/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCSettingsViewController.h"
#import "DCServerCommunicator.h"

@interface DCSettingsViewController ()

@end

@implementation DCSettingsViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	NSString* token = [NSUserDefaults.standardUserDefaults stringForKey:@"token"];
	
	if(token.length)
		[self.tokenInputField setText:token];
}

- (void)viewWillDisappear:(BOOL)animated{
	[NSUserDefaults.standardUserDefaults setObject:self.tokenInputField.text forKey:@"token"];
	
	if(!DCServerCommunicator.sharedInstance.isReconnecting){
		[DCServerCommunicator.sharedInstance.websocket close];
		[DCServerCommunicator.sharedInstance reconnect];
	}
}

@end