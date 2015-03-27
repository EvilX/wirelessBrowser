//
//  AppDelegate.m
//  wirelessBrowser
//
//  Created by Nasedkin Leonid on 26.03.15.
//  Copyright (c) 2015 Nasedkin Leonid. All rights reserved.
//

#import "AppDelegate.h"
#import "wirelessBrowserController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    wirelessBrowserController *w = (wirelessBrowserController *)self.window;
    [w initView];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
