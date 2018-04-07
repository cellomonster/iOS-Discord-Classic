//
//  DCAppDelegate.m
//  Discord Classic
//
//  Created by Julian Triveri on 3/2/18.
//  Copyright (c) 2018 Julian Triveri. All rights reserved.
//

#import "DCAppDelegate.h"
#import "DCServerCommunicator.h"

@interface DCAppDelegate()
@property bool shouldReload;
@end

@implementation DCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOption{
	self.shouldReload = false;
	
	[UINavigationBar.appearance setBackgroundImage:[UIImage imageNamed:@"UINavigationBarTexture"] forBarMetrics:UIBarMetricsDefault];
	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application{
	NSLog(@"Will resign active");
}

- (void)applicationDidEnterBackground:(UIApplication *)application{
	NSLog(@"Did enter background");
	self.shouldReload = true;
}

- (void)applicationWillEnterForeground:(UIApplication *)application{
	NSLog(@"Will enter foreground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application{
	NSLog(@"Did become active");
	if(self.shouldReload && [NSUserDefaults.standardUserDefaults stringForKey:@"token"]){
		[DCServerCommunicator.sharedInstance sendResume];
	}
}

- (void)applicationWillTerminate:(UIApplication *)application{
	NSLog(@"Will terminate");
}

@end
