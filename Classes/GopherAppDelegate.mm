//
//  GopherAppDelegate.m
//  Gopher
//

//  Copyright 3dDogStudios 2010. All rights reserved.
//

#import "GopherAppDelegate.h"

#import "GopherGameController.h"
#if USE_OF
#import "OpenFeint.h"
#endif



@implementation GopherAppDelegate

@synthesize window;
@synthesize myViewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {

	application.statusBarHidden = YES;
	
	[[UIApplication sharedApplication ] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:NO];
	
	// create the goph game controller
	GopherGameController *gameController = 
	[[GopherGameController alloc] initWithNibName:@"GopherGameController" bundle:[NSBundle mainBundle]];
	
	[self setMyViewController:gameController];
	[gameController release];
	
	
	[window addSubview:[myViewController view]];
	
	myViewController.view.frame = window.frame;
	
	// keep from dimming screen
	[application setIdleTimerDisabled:YES];
	
}


- (void)applicationWillResignActive:(UIApplication *)application {
	
	[myViewController appPaused];
#if USE_OF	
	[OpenFeint applicationWillResignActive];
#endif
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
	[myViewController appResumed];
#if USE_OF
	[OpenFeint applicationDidBecomeActive];
#endif
}

- (void)dealloc {
#if USE_OF
	[OpenFeint shutdown];
#endif
	[window release];
	
	[myViewController release];
	
	[super dealloc];
}

@end
