//
//  wirelessBrowserController.h
//  wirelessBrowser
//
//  Created by Nasedkin Leonid on 26.03.15.
//  Copyright (c) 2015 Nasedkin Leonid. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <CorePlot/CorePlot.h>

@interface wirelessBrowserController : NSWindow <NSTableViewDataSource, NSTableViewDelegate,CPTPlotDataSource>
@property CWInterface *interface;
@property NSArray *networkList;
@property NSMutableDictionary *plotData;
@property BOOL scanEnabled;
-(void) scannerProcess;
-(void) initView;
@end
