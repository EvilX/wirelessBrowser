//
//  wirelessBrowserController.m
//  wirelessBrowser
//
//  Created by Nasedkin Leonid on 26.03.15.
//  Copyright (c) 2015 Nasedkin Leonid. All rights reserved.
//

#import <CoreWLAN/CoreWLAN.h>
#import <CorePlot/CorePlot.h>
#import "wirelessBrowserController.h"

@interface wirelessBrowserController ()
@property (weak) IBOutlet NSTableView *wirelessTable;
@property (weak) IBOutlet CPTGraphHostingView *wirelessGraph;
@property (nonatomic, readwrite, strong) CPTXYGraph *graph;

@property (weak) IBOutlet NSToolbarItem *startScanButton;
- (IBAction)startScan:(id)sender;

@end

@implementation wirelessBrowserController

@synthesize interface, networkList, scanEnabled;

-(void) initView {
    self.interface = [[CWInterface alloc] initWithInterfaceName:@"en1"];
        //[self.wirelessTable setDelegate:self];
    self.wirelessTable.dataSource = self;
    self.wirelessTable.delegate = self;
    self.scanEnabled = false;

    CPTXYGraph *newGraph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    CPTTheme *theme      = [CPTTheme themeNamed:kCPTDarkGradientTheme];
    [newGraph applyTheme:theme];
    self.graph = newGraph;
    self.wirelessGraph.hostedGraph = newGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)newGraph.defaultPlotSpace;

    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-1) length:CPTDecimalFromInt(16)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-8) length:CPTDecimalFromInt(115)];
    
    NSNumberFormatter *formatter = [NSNumberFormatter alloc];
    [formatter setNumberStyle: NSNumberFormatterNoStyle];
    [formatter setGeneratesDecimalNumbers:FALSE];
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)newGraph.axisSet;
    CPTXYAxis *x          = axisSet.xAxis;
    x.majorIntervalLength         = CPTDecimalFromDouble(1);
    x.orthogonalCoordinateDecimal = CPTDecimalFromDouble(2.0);
    x.minorTicksPerInterval       = 0;
    x.labelFormatter = formatter;

    CPTXYAxis *y = axisSet.yAxis;
    y.majorIntervalLength         = CPTDecimalFromDouble(10);
    y.minorTicksPerInterval       = 5;
    y.orthogonalCoordinateDecimal = CPTDecimalFromDouble(0);
    y.labelFormatter = formatter;
    
    CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] init];
    dataSourceLinePlot.identifier = @"WiFi netoworks";
    
    CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
    lineStyle.lineWidth              = 3.0;
    lineStyle.lineColor              = [CPTColor greenColor];
    dataSourceLinePlot.dataLineStyle = lineStyle;
    
    dataSourceLinePlot.dataSource = self;
    [newGraph addPlot:dataSourceLinePlot];
    
}

-(void) scannerProcess {
    if (!self.scanEnabled) {
        return;
    }
    NSError* error;
    self.networkList = [interface scanForNetworksWithName:nil error:&error];
    NSLog(@"SCANNER");
    if (error) {
        NSLog(@"ERROR %@", [error description]);
    }
    [self.wirelessTable reloadData];
    [self.graph reloadData];
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(scannerProcess)
                                   userInfo:nil
                                    repeats:NO];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSLog(@"COUNT");
    return self.networkList.count;
}

-(NSString*) getNetworkValue:(NSInteger)row :(NSString*)identifier {
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"rssi"
                                                                   ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray = [[self.networkList allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    CWNetwork* net = [sortedArray objectAtIndex:row];
    CWChannel *channel = net.wlanChannel;
    if ([identifier isEqualToString:@"ssid"]) {
        return (id)net.ssid;
    }
    if ([identifier isEqualToString:@"bssid"]) {
        return (id)net.bssid;
    }
    if ([identifier isEqualToString:@"band"]) {
        if (channel.channelBand == kCWChannelBand2GHz) {
            return @"2.4 GHz";
        } else if (channel.channelBand == kCWChannelBand5GHz) {
            return @"5 GHz";
        } else {
            return @"Unknown";
        }
    }
    if ([identifier isEqualToString:@"channelNumber"]) {
        NSString *width;
        if (channel.channelWidth == kCWChannelWidth20MHz) {
            width = @"20MHz";
        } else if (channel.channelWidth == kCWChannelWidth40MHz) {
            width = @"40MHz";
        } else if (channel.channelWidth == kCWChannelWidth80MHz) {
            width = @"80MHz";
        } else if (channel.channelWidth == kCWChannelWidth160MHz) {
            width = @"160MHz";
        } else if (channel.channelWidth == kCWChannelWidthUnknown) {
            width = @"-";
        }
        return (id)[NSString stringWithFormat:@"%li (%@)", (long)channel.channelNumber, width];
    }
    if ([identifier isEqualToString:@"channelNumber_only"]) {
        return (id)[NSString stringWithFormat:@"%li", (long)channel.channelNumber];
    }
    if ([identifier isEqualToString:@"rssi"]) {
        return (id)[NSString stringWithFormat:@"%li/%li", net.rssiValue, net.noiseMeasurement];
    }
    if ([identifier isEqualToString:@"rssi_only"]) {
        return (id)[NSString stringWithFormat:@"%li", net.rssiValue];
    }
    
    if ([identifier isEqualToString:@"country"]) {
        return (id)net.countryCode;
    }
    if ([identifier isEqualToString:@"beacon"]) {
        return (id)[NSString stringWithFormat:@"%li", net.beaconInterval];
    }
    if ([identifier isEqualToString:@"security"]) {
        NSMutableArray *sec = [[NSMutableArray alloc] init];
        /*
         kCWSecurityNone                 = 0,
         kCWSecurityWEP                  = 1,
         kCWSecurityWPAPersonal          = 2,
         kCWSecurityWPAPersonalMixed     = 3,
         kCWSecurityWPA2Personal         = 4,
         kCWSecurityPersonal             = 5,
         kCWSecurityDynamicWEP           = 6,
         kCWSecurityWPAEnterprise        = 7,
         kCWSecurityWPAEnterpriseMixed   = 8,
         kCWSecurityWPA2Enterprise       = 9,
         kCWSecurityEnterprise           = 10,
         kCWSecurityUnknown
         */
        if ([net supportsSecurity:kCWSecurityNone]) {
            [sec addObject:@"Insecure"];
        }
        if ([net supportsSecurity:kCWSecurityWEP]) {
            [sec addObject:@"WEP"];
        }
        if ([net supportsSecurity:kCWSecurityWPAPersonal]) {
            [sec addObject:@"WPA Personal"];
        }
            //        if ([net supportsSecurity:kCWSecurityWPAPersonalMixed]) {
            //            [sec addObject:@"WPA Personal Mixed"];
            //        }
        if ([net supportsSecurity:kCWSecurityWPA2Personal]) {
            [sec addObject:@"WPA2 Personal"];
        }
            //        if ([net supportsSecurity:kCWSecurityPersonal]) {
            //            [sec addObject:@"Personal"];
            //        }
        if ([net supportsSecurity:kCWSecurityDynamicWEP]) {
            [sec addObject:@"Dynamic WEP"];
        }
        if ([net supportsSecurity:kCWSecurityWPAEnterprise]) {
            [sec addObject:@"WPA Enerprise"];
        }
            //        if ([net supportsSecurity:kCWSecurityWPAEnterpriseMixed]) {
            //            [sec addObject:@"WPA Enerprise Mixed"];
            //        }
        if ([net supportsSecurity:kCWSecurityWPA2Enterprise]) {
            [sec addObject:@"WPA2 Enterprise"];
        }
            //        if ([net supportsSecurity:kCWSecurityEnterprise]) {
            //            [sec addObject:@"Enterprise"];
            //        }
        if ([net supportsSecurity:kCWSecurityUnknown]) {
            [sec addObject:@"UNKNOWN"];
        }
        return (id)[sec componentsJoinedByString:@"\n"];
    }
    
    return @"";
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self getNetworkValue:row:tableColumn.identifier];
}

-(NSUInteger) numberOfRecordsForPlot:(CPTPlot *)plot {
    NSLog(@"COUNT PLOT");
    return self.networkList.count * 3;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    NSString *value = [self getNetworkValue:row :@"security"];
    NSInteger lines = [[value componentsSeparatedByCharactersInSet:
                        [NSCharacterSet newlineCharacterSet]] count];
    return self.wirelessTable.rowHeight * lines;
}

- (IBAction)startScan:(id)sender {
    if (!self.scanEnabled) {
        self.scanEnabled = true;
        self.startScanButton.image = [NSImage imageNamed:@"NSStatusUnavailable"];
        self.startScanButton.label = @"Stop scan";
        [NSTimer scheduledTimerWithTimeInterval:0.5
                                         target:self
                                       selector:@selector(scannerProcess)
                                       userInfo:nil
                                        repeats:NO];
    } else {
        self.scanEnabled = false;
        self.startScanButton.image = [NSImage imageNamed:@"NSStatusAvailable"];
        self.startScanButton.label = @"Start scan";
    }
}

-(double)doubleForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx {
    
    NSInteger d = idx % 3;
    NSLog(@"%li %li", idx, d);
    double xVal = 0;
    double yVal = 0;
    NSString *channel = [self getNetworkValue:(idx/3) :@"channelNumber_only"];
    if (d == 0) {
        xVal = channel.integerValue - 1;
    } else if (d == 2) {
        xVal = channel.integerValue + 1;
    } else {
        yVal = 100 + [self getNetworkValue:(idx/3) :@"rssi_only"].integerValue;
        xVal = channel.integerValue;
    }
    NSLog(@"%f %f", xVal, yVal);
    if (fieldEnum == CPTScatterPlotFieldX) {
        return xVal;
    } else {
        return yVal;
    }
//    return @{ @(CPTScatterPlotFieldX): @(xVal),
//              @(CPTScatterPlotFieldY): @(yVal) };
}

@end
