//
//  DCViewController.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/4/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCViewController.h"
#import "DCServerCommunicator.h"
#import "DCGuildListViewController.h"

@implementation DCViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	
	[DCServerCommunicator.sharedInstance startCommunicator];
	
	[self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"Background.tiff"]]];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end