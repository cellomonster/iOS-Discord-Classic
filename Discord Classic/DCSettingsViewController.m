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
@property (strong, nonatomic) IBOutlet UISwitch *permissionCalculationToggle;
@end

@implementation DCSettingsViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	NSString* token = [NSUserDefaults.standardUserDefaults stringForKey:@"token"];
	
	if(token)
		[self.tokenInputField setText:token];
	
	bool permissionCalculationEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"perm calc"];
	
	if([NSUserDefaults.standardUserDefaults.dictionaryRepresentation.allKeys containsObject:@"perm calc"])
		[self.permissionCalculationToggle setOn:permissionCalculationEnabled animated:NO];
}

- (void)viewWillDisappear:(BOOL)animated{
	[NSUserDefaults.standardUserDefaults setObject:self.tokenInputField.text forKey:@"token"];
	[NSUserDefaults.standardUserDefaults setBool:self.permissionCalculationToggle.on forKey:@"perm calc"];
	
	[DCServerCommunicator.sharedInstance reconnect];
}
@end