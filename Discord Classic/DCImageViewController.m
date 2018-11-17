//
//  DCImageViewController.m
//  Discord Classic
//
//  Created by Trevir on 11/17/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCImageViewController.h"

@interface DCImageViewController ()

@end

@implementation DCImageViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning{
	[super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
	[self setImageView:nil];
	[super viewDidUnload];
}
@end
