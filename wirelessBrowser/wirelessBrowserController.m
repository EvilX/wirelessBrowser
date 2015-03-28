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

#define GRAPH_SAMPLES 20

@interface wirelessBrowserController ()
@property (weak) IBOutlet NSTableView *wirelessTable;
@property (weak) IBOutlet CPTGraphHostingView *wirelessGraph24;
@property (weak) IBOutlet CPTGraphHostingView *wirelessGraph5;
@property (nonatomic, readwrite, strong) CPTXYGraph *graph24; //2.4 GHz
@property (nonatomic, readwrite, strong) CPTXYGraph *graph5; //5GHz

@property (weak) IBOutlet NSToolbarItem *startScanButton;
- (IBAction)startScan:(id)sender;

@end

@implementation wirelessBrowserController

@synthesize interface, networkList, scanEnabled, plotData;

-(void) initView {
    self.wirelessTable.dataSource = self;
    self.wirelessTable.delegate = self;
    self.scanEnabled = false;
    [self initGraph];
    
    NSSet *interfaces = [CWInterface interfaceNames];
    if (interfaces.count) {
        self.interface = [[CWInterface alloc] initWithInterfaceName:[[interfaces allObjects] objectAtIndex:0]];
        //[self.wirelessTable setDelegate:self];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        self.interface = nil;
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:NSLocalizedString(@"There is no wireless interfaces on your mac",
                                                @"There is no wireless interfaces on your mac")];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert runModal];
        self.startScanButton.enabled = NO;
    }
}

-(void) initGraph {
        //Prepare plot data
        //2.4GHz
    CPTXYGraph *graph24 = [[CPTXYGraph alloc] initWithFrame:CGRectZero xScaleType:CPTScaleTypeLinear
                                                 yScaleType:CPTScaleTypeLinear];
    CPTXYGraph *graph5 = [[CPTXYGraph alloc] initWithFrame:CGRectZero xScaleType:CPTScaleTypeLinear
                                                 yScaleType:CPTScaleTypeLog];
    CPTTheme *theme      = [CPTTheme themeNamed:kCPTDarkGradientTheme];
    [graph24 applyTheme:theme];
    [graph5 applyTheme:theme];
    self.graph24 = graph24;
    self.graph5 = graph5;
    self.wirelessGraph24.hostedGraph = graph24;
    self.wirelessGraph5.hostedGraph = graph5;
    
    NSNumberFormatter *formatter = [NSNumberFormatter alloc];
    [formatter setNumberStyle: NSNumberFormatterNoStyle];
    [formatter setGeneratesDecimalNumbers:FALSE];
    
        //Axes
        // 2.4GHz
    CPTXYPlotSpace *plotSpace24 = (CPTXYPlotSpace *)graph24.defaultPlotSpace;
    plotSpace24.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-1) length:CPTDecimalFromInt(16)];
    plotSpace24.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-8) length:CPTDecimalFromInt(100)];

    CPTXYAxisSet *axisSet24 = (CPTXYAxisSet *)graph24.axisSet;
    CPTXYAxis *x24          = axisSet24.xAxis;
    x24.majorIntervalLength         = CPTDecimalFromDouble(1);
    x24.orthogonalCoordinateDecimal = CPTDecimalFromDouble(2.0);
    x24.minorTicksPerInterval       = 0;
    x24.labelFormatter = formatter;
    CPTXYAxis *y24 = axisSet24.yAxis;
    y24.majorIntervalLength         = CPTDecimalFromDouble(10);
    y24.minorTicksPerInterval       = 5;
    y24.orthogonalCoordinateDecimal = CPTDecimalFromDouble(0);
    y24.labelFormatter = formatter;
    
        //5GHz
    CPTXYPlotSpace *plotSpace5 = (CPTXYPlotSpace *)graph5.defaultPlotSpace;
    plotSpace5.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(25) length:CPTDecimalFromInt(160)];
    plotSpace5.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(-8) length:CPTDecimalFromInt(100)];
    
    CPTXYAxisSet *axisSet5 = (CPTXYAxisSet *)graph5.axisSet;
    CPTXYAxis *x5          = axisSet5.xAxis;
    x5.majorIntervalLength         = CPTDecimalFromDouble(10);
    x5.orthogonalCoordinateDecimal = CPTDecimalFromDouble(2.0);
    x5.minorTicksPerInterval       = 0;
    x5.labelFormatter = formatter;

    CPTXYAxis *y5 = axisSet5.yAxis;
    y5.majorIntervalLength         = CPTDecimalFromDouble(10);
    y5.minorTicksPerInterval       = 5;
    y5.orthogonalCoordinateDecimal = CPTDecimalFromDouble(30);
    y5.labelFormatter = formatter;
}

-(void) scannerProcess {
    if (!self.scanEnabled) {
        return;
    }
    NSError* error;
    NSSet *networkSet = [interface scanForNetworksWithName:nil error:&error];
    if (error) {
        NSLog(@"ERROR %@", [error description]);
    }
    [self processNetoworkList:networkSet];
    [self.wirelessTable reloadData];
    [self preparePlot];
    [self.graph24 reloadData];
    [self.graph5 reloadData];
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(scannerProcess)
                                   userInfo:nil
                                    repeats:NO];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.networkList.count;
}

-(void) processNetoworkList:(NSSet*) networkSet {
        // Prepare network list for visualisation
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"rssi"
                                                                   ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    self.networkList = [[networkSet allObjects] sortedArrayUsingDescriptors:sortDescriptors];
}

-(void) preparePlot {
    CGFloat green = 1.0;
    CGFloat red = 0;
    CGFloat blue = 0;
    self.plotData = [[NSMutableDictionary alloc] init];
        //Build plots and plot values
    for (int i = 0; i < self.networkList.count; i++) {
        NSString *ssid = [self getNetworkValue:i :@"ssid"];
        NSString *band = [self getNetworkValue:i :@"band"];
        NSString *ident = [NSString stringWithFormat:@"%@(%@)", ssid, band];
        long channel = [self getNetworkValue:i :@"channelNumber_only"].integerValue;
        double rssi = [self getNetworkValue:i :@"rssi_only"].floatValue;
        double noise = [self getNetworkValue:i :@"noise_only"].floatValue;
        if (rssi < noise) {
            continue;
        }
//        long width = [self getNetworkValue:i :@"channelWidth"].integerValue;
        
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] init];
        dataSourceLinePlot.identifier = ident;
    
        CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 1.0;
            //build color
        if (red == 0.5) {
            if (blue == 0.5) {
                if (green > 0.0) {
                    green = green - 0.2f;
                }
            } else {
                blue = blue + 0.2f;
            }
        } else {
            red = red + 0.2f;
        }
        
        
        lineStyle.lineColor = [CPTColor colorWithComponentRed:red green:green blue:blue alpha:1.0];
        dataSourceLinePlot.dataLineStyle = lineStyle;
        dataSourceLinePlot.title = ssid;
        dataSourceLinePlot.dataSource = self;
        
        if (channel < 16) {
            if (![self.graph24 plotWithIdentifier:ident]) {
                [self.graph24 addPlot:dataSourceLinePlot];
            }
        } else {
            if (![self.graph5 plotWithIdentifier:ident]) {
                [self.graph5 addPlot:dataSourceLinePlot];
            }
        }
            // Create plot data
            // 10 points per graph
        NSMutableArray *data = [[NSMutableArray alloc] init];
        double minX = channel - 2;
        double maxX = channel + 2;
        double step = (maxX - minX) / GRAPH_SAMPLES;
        double lastY = -1;
        for (double x = minX; x < (maxX + step); x += step) {
//            double y = ((-(pow((x - channel), 2)) + 4)) * pow(5 - 10/exp(noise/rssi), 2);
            double y = ((-(pow((x - channel), 2)) + 4) * 25) * ((100 + rssi)/100);
            if ((lastY == 0) && (y <= 0)) {
                break;
            }
            if (y < 0 ) {
                y = 0;
            }
            lastY = y;
            NSArray *sample = @[[NSNumber numberWithDouble:x], [NSNumber numberWithDouble:y]];
            [data addObject:sample];
        }
        [self.plotData setObject:data forKey:ident];
    }
}

-(NSString*) getNetworkValue:(NSInteger)row :(NSString*)identifier {
    CWNetwork* net = [self.networkList objectAtIndex:row];
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
    if ([identifier isEqualToString:@"channelWidth"]) {
        long width;
        if (channel.channelWidth == kCWChannelWidth20MHz) {
            width = 20;
        } else if (channel.channelWidth == kCWChannelWidth40MHz) {
            width = 40;
        } else if (channel.channelWidth == kCWChannelWidth80MHz) {
            width = 80;
        } else if (channel.channelWidth == kCWChannelWidth160MHz) {
            width = 160;
        } else if (channel.channelWidth == kCWChannelWidthUnknown) {
            width = 22;
        }
        return (id)[NSString stringWithFormat:@"%li", width];
    }
    if ([identifier isEqualToString:@"rssi"]) {
        return (id)[NSString stringWithFormat:@"%li/%li", net.rssiValue, net.noiseMeasurement];
    }
    if ([identifier isEqualToString:@"rssi_only"]) {
        return (id)[NSString stringWithFormat:@"%li", net.rssiValue];
    }
    if ([identifier isEqualToString:@"noise_only"]) {
        return (id)[NSString stringWithFormat:@"%li", net.noiseMeasurement];
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
    
    return @" ";
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self getNetworkValue:row:tableColumn.identifier];
}

-(NSUInteger) numberOfRecordsForPlot:(CPTPlot *)plot {
    NSArray *data = [self.plotData objectForKey:plot.identifier];
    if (data) {
        return data.count;
    }
    return 0;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    NSString *value = [self getNetworkValue:row :@"security"];
    NSInteger lines = [[value componentsSeparatedByCharactersInSet:
                        [NSCharacterSet newlineCharacterSet]] count];
    return self.wirelessTable.rowHeight * lines;
}

- (IBAction)startScan:(id)sender {
    if (!self.scanEnabled && self.interface) {
        self.scanEnabled = true;
        self.startScanButton.image = [NSImage imageNamed:@"NSStatusUnavailable"];
        self.startScanButton.label = NSLocalizedString(@"Stop scan", @"Stop scan");
        [NSTimer scheduledTimerWithTimeInterval:0.5
                                         target:self
                                       selector:@selector(scannerProcess)
                                       userInfo:nil
                                        repeats:NO];
    } else {
        self.scanEnabled = false;
        self.startScanButton.image = [NSImage imageNamed:@"NSStatusAvailable"];
        self.startScanButton.label = NSLocalizedString(@"Start scan", @"Start scan");
    }
}

-(double)doubleForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx {
    NSArray *data = [self.plotData objectForKey:plot.identifier];
    if ([self.plotData objectForKey:plot.identifier]) {
        NSArray *sample = [data objectAtIndex:idx];
        if (fieldEnum == CPTScatterPlotFieldX) {
            NSNumber *value = [sample objectAtIndex:0];
            return [value doubleValue];
        } else {
            NSNumber *value = [sample objectAtIndex:1];
            return [value doubleValue];
        }
    }
    return 0;
}

-(CPTLayer*)dataLabelForPlot:(CPTPlot *)plot recordIndex:(NSUInteger)idx {
    NSArray *data = [self.plotData objectForKey:plot.identifier];
    if ([self.plotData objectForKey:plot.identifier]) {
        if ((data.count/2) == idx) {
            CPTTextLayer *label = [[CPTTextLayer alloc] initWithText:(NSString*)plot.identifier];
            CPTMutableTextStyle *titleText = [CPTMutableTextStyle textStyle];
            titleText.color = [CPTColor whiteColor];
            label.textStyle = titleText;

            return label;
        }
    }
    return nil;
}

@end
