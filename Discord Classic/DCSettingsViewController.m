//
//  DCSettingsViewController.m
//  Discord Classic
//
//  Created by Trevir on 3/18/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCSettingsViewController.h"
#import "DCServerCommunicator.h"

@implementation DCSettingsViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	NSString* token = [NSUserDefaults.standardUserDefaults stringForKey:@"token"];
	
	if(token)
		[self.tokenInputField setText:token];
}

- (void)viewWillDisappear:(BOOL)animated{
	[NSUserDefaults.standardUserDefaults setObject:self.tokenInputField.text forKey:@"token"];
	
	if(![DCServerCommunicator.sharedInstance.token isEqual:[NSUserDefaults.standardUserDefaults valueForKey:@"token"]]){
		DCServerCommunicator.sharedInstance.token = self.tokenInputField.text;
		[DCServerCommunicator.sharedInstance reconnect];
		
	}
}

- (IBAction)openTutorial:(id)sender {
	[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://www.youtube.com/watch?v=NWB3fGafJwk"]];
}

@end