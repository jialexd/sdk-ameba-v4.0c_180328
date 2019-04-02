/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The primary view controller for this app.
 */

#import "ViewController.h"
#import "ChatViewController.h"
#import "Cell.h"
#import "KxMenu.h"
#import "SettingPageViewController.h"
#include <ifaddrs.h>
#include <arpa/inet.h>



uint8_t const mCmdPrefix[] = { 0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54 };
uint8_t const mCmdGetAllSetting[] = { 0x02, 0x00, 0x0f };
uint8_t const unGroupCommand[] = { 0x00, 0x00, 0x20, 0x02, 0x1f, 0x41, 0x01, 0x00, 0x01, 0x00 };
uint8_t const serverCreatCommand[] = { 0x00, 0x00, 0x10, 0x02, 0x1f, 0x41 };
uint8_t const serverConnectCommand[] = { 0x00, 0x40, 0x06 };
uint8_t const portTOByte[] = { 0x1f, 0x41 };
uint8_t const groupCmd[] = { 0x00, 0x01, 0x00, 0x01 };
char gAddressString[INET6_ADDRSTRLEN];

NSUInteger IDforGroup = 1;
NSInteger IDforUnGroup = -1;
NSString *kDetailedViewControllerID = @"DetailView";    // view controller storyboard id
NSString *kCellID = @"cellID";                          // UICollectionViewCell storyboard id
NSInteger maxDeviceNumber = 32;
NSString *UART_CONTROL_TYPE=@"_uart_control._tcp.local.";
UICollectionViewLayoutAttributes *collectionCell;
Boolean isFindServiceDone = FALSE;
UIImageView *dragImageView;
NSString * mBrowserType;
NSTimer * scanTimer;
int scancount = 0;

UIAlertView *alert;
NSOutputStream *outputStream;
NSInputStream *inputStream;
NSData *output;
NSIndexPath *longPressIndexPath;

//NSMutableArray *IOTInfoArray;
NSMutableArray *IOTItemListArray;

@implementation ViewController

@synthesize IOTInfoArray = _IOTInfoArray;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize controlServicesArray = _controlServicesArray;
@synthesize dataServicesArray = _dataServicesArray;
@synthesize selectedService = _selectedService;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [[UIImage imageNamed:@"background.png"] drawInRect:self.view.bounds];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();   
    
    UIView * bgView = [UIView new];
    
    bgView.backgroundColor = [UIColor colorWithPatternImage:bgImage];
    //bgView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]];
    bgView.contentMode = UIViewContentModeScaleToFill;
    self.collectionView.backgroundView = bgView;
    _IOTInfoArray = [[NSMutableArray alloc] init];
    IOTItemListArray = [[NSMutableArray alloc] init];
    self.dataServicesArray = [[NSMutableArray alloc] init];
    self.title = @"Uart Adapter";
    output = nil;
    //  self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    //  self.netServiceBrowser.delegate = self;
    
    //NSString *browseType;
    // if (self.selectedService == nil) {
    //     browseType = @"_services._dns-sd._udp.";
    //     self.title = @"Bonjour Browser";
    // } else {
    //   NSString *fullDomainName = [NSString stringWithFormat:@"%@.%@", self.selectedService.name, self.selectedService.type];
    
    // }
    
    //[NSThread detachNewThreadSelector:@selector(startDiscover:) toTarget:self withObject:UART_CONTROL_TYPE];
    [self startDiscover:UART_CONTROL_TYPE];
    // [self.netServiceBrowser stop];
    //self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    //self.netServiceBrowser.delegate = self;
    //[self startDiscover:UART_DATA_TYPE];
    UILongPressGestureRecognizer *lpgr
    = [[UILongPressGestureRecognizer alloc]
       initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = .5; //seconds
    lpgr.delegate = self;
    lpgr.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:lpgr];
}

- (IBAction) scanButton {
    scancount = 0;

    
    [self closeDiscover];
    
    [self startDiscover:UART_CONTROL_TYPE];
    
}

-(void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint p = [gestureRecognizer locationInView:self.collectionView];
    
    longPressIndexPath = [self.collectionView indexPathForItemAtPoint:p];
    if (longPressIndexPath == nil){
        NSLog(@"couldn't find index path");
    } else {
        // get the cell at indexPath (the one you long pressed)
        collectionCell = [self.collectionView layoutAttributesForItemAtIndexPath:longPressIndexPath];
        
        struct _IOTInfo IOTItemLongPressed;
        [[IOTItemListArray objectAtIndex:longPressIndexPath.row] getValue:&IOTItemLongPressed];
        
        [self showMenu:IOTItemLongPressed.groupID];
      
    }
}


- (void)didLongPressCell:(UIPanGestureRecognizer *)sender
{
    NSInteger tag = sender.view.tag;
 
    CGPoint pressPoint = [sender locationInView:self.view];
        
    UIImage *img;
    Cell *dragCell;
    CGFloat w, h;
    CGFloat centerX, centerY;
    
    for (id view in self.collectionView.subviews) {
        if ([view isKindOfClass:[Cell class]]) {
            Cell *cc = (Cell *)view;
            if (cc.tag == tag) {
                dragCell = cc;
                break;
            }
        }
    }

    w = dragCell.image.bounds.size.width ;// 88;
    h = dragCell.image.bounds.size.height;//84;
    centerX = pressPoint.x-w/2;
    centerY = pressPoint.y-h/2;
    
    if (sender.state == UIGestureRecognizerStateBegan) {
      
        dragImageView = [[UIImageView alloc] initWithFrame:CGRectMake(centerX, centerY, w, h)];
        dragImageView.layer.shadowColor = [[UIColor blackColor] CGColor];
        dragImageView.layer.shadowOffset = CGSizeMake(2, 2);
        dragImageView.layer.shadowOpacity = 0.4f;
        dragImageView.image = dragCell.image.image;
        [self.view addSubview:dragImageView];

        dragCell.hidden = YES;
    }
    
    if (sender.state == UIGestureRecognizerStateChanged) {

        dragImageView.frame = CGRectMake(centerX, centerY, w, h);
        
       
        
    }
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        
      

        img = nil;
        dragImageView.image = nil;
        [dragImageView removeFromSuperview];
      
        dragCell.hidden = NO;
       
        
      
        
        for (id view in self.collectionView.subviews) {
            if ([view isKindOfClass:[Cell class]]) {
                Cell *overlapCell = (Cell *)view;
                if (overlapCell.tag != tag) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        alert = [[UIAlertView alloc] initWithTitle:@"UART Adapter" message:@"Groupping" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
                        [alert show];
                    });
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                        [alert dismissWithClickedButtonIndex:2 animated:YES];
                    });
                    
                    CGFloat minX = overlapCell.frame.origin.x - w;
                    CGFloat maxX = overlapCell.frame.origin.x + overlapCell.frame.size.width;
                    CGFloat minY = overlapCell.frame.origin.y - h;
                    CGFloat maxY = overlapCell.frame.origin.y + overlapCell.frame.size.height;
                    
                    if ((minX <= centerX && centerX <= maxX) && (minY <= centerY && centerY <= maxY)) {
                      

                        
                       
                        
                        char source[INET6_ADDRSTRLEN], destination[INET6_ADDRSTRLEN];
                        
                        struct _IOTInfo IOTDevice;
                        bool idIsEqual;
                        
                        
                        do{
                            idIsEqual = false;
                            for (int i = 0; i < IOTItemListArray.count; i++) {
                                [[IOTItemListArray objectAtIndex:i] getValue:&IOTDevice];
                                if (IOTDevice.groupID == IDforGroup && IOTDevice.groupID != 0) {
                                    idIsEqual = true;
                                    IDforGroup++;
                                    break;
                                }
                            }
                        }while (idIsEqual /*|| IOTItemListArray.count <= dragCell.tag*/);
                        
                        [[IOTItemListArray objectAtIndex:dragCell.tag] getValue:&IOTDevice];
                        [self prepareForInitNetworkCommunication:[IOTDevice.service.addresses objectAtIndex:0 ] Port:(int)IOTDevice.service.port];
                        [self devicePerformAction:1 GroupID:-1 Target:nil ];
                            [inputStream close];
                            [outputStream close];
                        
                        memcpy(source, gAddressString, INET6_ADDRSTRLEN);
                        
                        [[IOTItemListArray objectAtIndex:overlapCell.tag] getValue:&IOTDevice];
                        [self prepareForInitNetworkCommunication:[IOTDevice.service.addresses objectAtIndex:0 ] Port:(int)IOTDevice.service.port];
                        [self devicePerformAction:1 GroupID:-1 Target:nil ];
                            [inputStream close];
                            [outputStream close];
                      
                        memcpy(destination, gAddressString, INET6_ADDRSTRLEN);
                        
                        [[IOTItemListArray objectAtIndex:dragCell.tag] getValue:&IOTDevice];
                        [self prepareForInitNetworkCommunication:[IOTDevice.service.addresses objectAtIndex:0 ] Port:(int)IOTDevice.service.port];
                        [self devicePerformAction:2 GroupID:IDforGroup Target:destination];
                            [inputStream close];
                            [outputStream close];
                    
                        [[IOTItemListArray objectAtIndex:overlapCell.tag] getValue:&IOTDevice];
                        [self prepareForInitNetworkCommunication:[IOTDevice.service.addresses objectAtIndex:0 ] Port:(int)IOTDevice.service.port];
                        [self devicePerformAction:2 GroupID:IDforGroup Target:source];
                        [inputStream close];
                        [outputStream close];
                      
                       
                        
                        break;
                    }
                    

                }
            }
            
        }
        
        //IOTItemListArray=nil;
        //[self.collectionView reloadData];
        //[self performSelector:@selector(scanButton)];
        //}
        
       
    }
}


-(void) startDiscover:(NSString *)browseType
{
    _IOTInfoArray = [[NSMutableArray alloc] init];
    IOTItemListArray = [[NSMutableArray alloc] init];
    
    self.controlServicesArray = [[NSMutableArray alloc] init];
    self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    self.netServiceBrowser.delegate = self;
    
    NSArray *domainNameParts = [browseType componentsSeparatedByString:@"."];
    
    mBrowserType = [NSString stringWithFormat:@"%@.%@.", [domainNameParts objectAtIndex:0], [domainNameParts objectAtIndex:1]];
    alert = [[UIAlertView alloc] initWithTitle:@"UART Adapter" message:@"Scanning" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
    [alert show];


    [self.netServiceBrowser searchForServicesOfType:mBrowserType inDomain:@""];
    
    scanTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(repeatScan:) userInfo:nil repeats:YES];
    


}


- (void) repeatScan:(NSTimer *) aTimer{
    
    if(scancount >= 3){
       [scanTimer invalidate];
        [self.netServiceBrowser stop];
        self.netServiceBrowser.delegate = nil;
    
        [alert dismissWithClickedButtonIndex:1 animated:true];
        return;
    }
  
    [self.netServiceBrowser stop];
    self.netServiceBrowser.delegate = nil;
    
    
  
    
  
    self.netServiceBrowser.delegate = self;
    [self.netServiceBrowser searchForServicesOfType:mBrowserType inDomain:@""];
    scancount++;
}

-(void) closeDiscover
{
    [self.netServiceBrowser stop];

    self.netServiceBrowser.delegate = nil;
    self.netServiceBrowser = nil;
    self.controlServicesArray = nil;
    self.selectedService = nil;
    _IOTInfoArray = nil;
    [[self collectionView] reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{

    return IOTItemListArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    struct _IOTInfo IOTDeviceItem;
    NSString *imageToLoad;
    
    // we're going to use a custom UICollectionViewCell, which will hold an image and its label
    //
    Cell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    
    // make the cell's title the actual NSIndexPath value
    
    
    
    [[IOTItemListArray objectAtIndex:indexPath.row] getValue:&IOTDeviceItem];
    
    if (IOTDeviceItem.groupID != 0) {
        cell.label.text = IOTDeviceItem.groupName;
        imageToLoad = @"ameba_group.png";
    }else{
        cell.label.text = IOTDeviceItem.service.name;
        // load the image for this cell
        imageToLoad = @"device.png";
       
    }
    cell.image.image = [UIImage imageNamed:imageToLoad];
    cell.tag = indexPath.row;
    
    UIPanGestureRecognizer *dragPressGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressCell:)];


    [cell addGestureRecognizer:dragPressGesture];

    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    
    struct _IOTInfo IOTDevice;
    [[IOTItemListArray objectAtIndex:indexPath.row] getValue:&IOTDevice];
    self.selectedService = IOTDevice.service;

    collectionCell = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
   
    isFindServiceDone = FALSE;
   
    if (IOTDevice.groupID == 0)
        [self pushToChat:nil];
    else
        [[self collectionView] deselectItemAtIndexPath:indexPath animated:true];
}


- (void)showMenu:(NSInteger)groupID
{

    IDforUnGroup = groupID;
    NSArray *menuItems =
    @[
      [KxMenuItem menuItem:@"ACTION MENU"
                     image:nil
                    target:nil
                    action:NULL],
      
      [KxMenuItem menuItem:@"Setting"
                     image:[UIImage imageNamed:@"settings"]
                    target:self
                    action:@selector(pushToSetting:)],
      ];
      
    NSMutableArray *extraItems = [NSMutableArray arrayWithArray:menuItems];
    if (groupID != 0) {
        [extraItems addObject:[KxMenuItem menuItem:@"UnGroup"
                                           image:[UIImage imageNamed:@"ungroup"]
                                          target:self
                                            action:@selector(unGroup:)]];
    }
    

    
    KxMenuItem *first = menuItems[0];
    first.foreColor = [UIColor colorWithRed:47/255.0f green:112/255.0f blue:225/255.0f alpha:1.0];
    first.alignment = NSTextAlignmentCenter;
    if (groupID != 0)
        [KxMenu showMenuInView:self.view
                fromRect:collectionCell.frame
                menuItems:extraItems];
    else
        [KxMenu showMenuInView:self.view
                  fromRect:collectionCell.frame
                 menuItems:menuItems];

}

-(void) unGroup:(id)sender
{

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [alert dismissWithClickedButtonIndex:2 animated:YES];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        alert = [[UIAlertView alloc] initWithTitle:@"UART Adapter" message:@"Ungroupping" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
        [alert show];
    });
   
    

        struct _IOTInfo IOTDevice;
    
        for (int i=0 ; i < _IOTInfoArray.count; i++) {
            [[_IOTInfoArray objectAtIndex:i] getValue:&IOTDevice];
            
            if (IOTDevice.groupID == IDforUnGroup) {

                [self prepareForInitNetworkCommunication:[IOTDevice.service.addresses objectAtIndex:0 ] Port:(int)IOTDevice.service.port];
                [self devicePerformAction:0 GroupID:-1 Target:nil];
                [inputStream close];
                [outputStream close];
            }
            for (int i=0 ; i < IOTItemListArray.count; i++) {
                [[IOTItemListArray objectAtIndex:i] getValue:&IOTDevice];

                if(IOTDevice.groupID == IDforUnGroup)
                    [IOTItemListArray removeObjectAtIndex:i];
            }
            
        }
   
        
              // [self.collectionView reloadData];
    
    //
    //[self performSelector:@selector(scanButton)];
   
    
}


- (void) pushToSetting:(id)sender
{

    

  

    alert = [[UIAlertView alloc] initWithTitle:@"UART Adapter" message:@"Connecting" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
  
    [alert show];

  

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
   
        self.selectedService = self.controlServicesArray[longPressIndexPath.row];

        while ( self.selectedService.port  < 0 ) {
            [self.selectedService resolveWithTimeout:5.0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                self.selectedService = self.controlServicesArray[longPressIndexPath.row];
                
            });
        }
        
        [self prepareForInitNetworkCommunication:[self.selectedService.addresses objectAtIndex:0] Port:(int)self.selectedService.port];
       
        [self queryAllSettings];

    });
    
}


- (void) pushToChat:(id)sender
{
//    NSIndexPath *selectedIndexPath = [self.collectionView indexPathsForSelectedItems][0];
//    ChatViewController *chatVC = [[ChatViewController alloc] init];
//    chatVC.selectedService = self.controlServicesArray[selectedIndexPath.row ];
    [self performSegueWithIdentifier:@"showDetail" sender:sender];
    //[self presentViewController:detailViewController animated:YES completion:nil];

}


- (void) queryAllSettings {
    
    NSMutableData *cmd = [[NSMutableData alloc] initWithBytes:mCmdPrefix length:sizeof(mCmdPrefix)];
    [cmd appendBytes:mCmdGetAllSetting length:sizeof(mCmdGetAllSetting)];
    [outputStream write:[cmd bytes] maxLength:[cmd length]];
   
}

- (void) devicePerformAction:(NSInteger)type GroupID:(NSInteger)groupID Target:(char *)iAddress
{
    
    uint8_t gID[] = {(uint8_t)groupID};
    NSMutableData *cmd = [[NSMutableData alloc] initWithBytes:mCmdPrefix length:sizeof(mCmdPrefix)];
    switch (type) {
        
        case 0: // ungroup

            [cmd appendBytes:unGroupCommand length:sizeof(unGroupCommand)];
            break;
        case 1: // server create
            [cmd appendBytes:serverCreatCommand length:sizeof(serverCreatCommand)];
            break;
        case 2: // group

            uint8_t ip[4] = {0};
            char  *marker, *ret;
            
            ret = strtok_r(iAddress, ".", &marker);
            ip[0] = (uint8_t)strtod(ret, NULL);
            ret = strtok_r(NULL, ".", &marker);
            ip[1] = (uint8_t)strtod(ret, NULL);
            ret = strtok_r(NULL, ".", &marker);
            ip[2] = (uint8_t)strtod(ret, NULL);
            ret = strtok_r(NULL, ".", &marker);
            ip[3] = (uint8_t)strtod(ret, NULL);
            ret = strtok_r(NULL, ".", &marker);
            

            [cmd appendBytes:groupCmd length:sizeof(groupCmd)];
            [cmd appendBytes:gID length:sizeof(gID)];
            [cmd appendBytes:serverConnectCommand length:sizeof(serverConnectCommand)];
            [cmd appendBytes:ip length:sizeof(ip)];
            [cmd appendBytes:portTOByte length:sizeof(portTOByte)];
            


            break;
            
        default:
            break;
    }
    [outputStream write:[cmd bytes] maxLength:[cmd length]];

}


-(void)prepareForInitNetworkCommunication:(NSData *)mAddress Port:(int)mPort {
    
    NSData *address = mAddress;
    char addressString[INET6_ADDRSTRLEN];
    int inetType;
    
    struct sockaddr_in6 addr6;
    memcpy(&addr6, address.bytes, address.length);
    
    if (address.length == 16) { // IPv4
        inetType = AF_INET;
        struct sockaddr_in addr4;
        memcpy(&addr4, address.bytes, address.length);
        inet_ntop(AF_INET, &addr4.sin_addr, addressString, 512);
        inet_ntop(AF_INET, &addr4.sin_addr, gAddressString, 512);
        [self initNetworkCommunication:[NSString stringWithCString:addressString encoding:NSASCIIStringEncoding] Port:mPort];
        
    }

    
}


- (void) initNetworkCommunication:(NSString *)mIP  Port:(int)mPort {
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)mIP, mPort, &readStream, &writeStream);
    
    inputStream = (__bridge NSInputStream *)readStream;
    outputStream = (__bridge NSOutputStream *)writeStream;
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream open];
    [outputStream open];
    
}
/*
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == [alertView cancelButtonIndex]){
        scancount = 12;

        [alertView dismissWithClickedButtonIndex:2 animated:YES];
    }
}
*/
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        scancount = 12;
        [scanTimer invalidate];
    }else if (buttonIndex == 2) {
        [self performSelector:@selector(scanButton)];

    }

}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    


    
    switch (streamEvent) {
            
        case NSStreamEventOpenCompleted:

            if (alert != nil)
                [alert dismissWithClickedButtonIndex:1 animated:true];
            break;
        case NSStreamEventHasBytesAvailable:
            
            if (theStream == inputStream) {
                
                uint8_t buffer[64] = {0};
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [[NSNumber numberWithInteger:[inputStream read:buffer maxLength: sizeof(buffer)]] intValue] ;
                    if (len > 0) {
                        
                        output = [[NSData alloc] initWithBytes:buffer length:len];

                        
                        if (nil != output) {
                            

                            if([self inputStreamReceivedParser:output] == 1)//update ui
                            {
                               
                                [self performSegueWithIdentifier:@"showSetting" sender:nil];
                                
                            }
                            
                        }
                    }
                }
            }
            break;
            
            
        case NSStreamEventErrorOccurred:
            
            NSLog(@"Can not connect to the host!");
            break;
            
        case NSStreamEventEndEncountered:
            
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
       
            theStream = nil;
            
            break;
        default:
            NSLog(@"Unknown event");
    }
    
    
    
    
}


- (int) inputStreamReceivedParser:(NSData *)message {
    
    uint8_t *recvCmd = (uint8_t *)[message bytes] ;
    
    int mBardRate = 0;
    int mDataBit = 0;
    int mParityBit = 0;
    int mStopBit = 0;
    

    
    if ([self checkPrefix:recvCmd]){
        int readbit = 10;
        
        if (recvCmd[readbit] == 0x01) { //response for ack
            return 0;//ok
        }else if (recvCmd[readbit] == 0x03) { //response for getting
            mBardRate = 0;
            mDataBit = 0;
            mParityBit = 0;
            mStopBit = 0;
            
            readbit+=2;
            do{

                if (recvCmd[readbit] == 0x01) { //baudrate
                    int bit = 0;
                    int tmp = 0;
                    
                    int byteLen = recvCmd[++readbit];
                    readbit++;
                    
                    for (int i=readbit; i < (readbit+byteLen); i++) {

                        tmp = (recvCmd[i] & 0xFF) << (8*bit);
                        mBardRate += tmp;
                        bit++;
                    }
                    readbit+=(byteLen+1);

                    
                }else if (recvCmd[readbit] == 0x02) { //data
                    int byteLen = recvCmd[++readbit];
                    readbit++;
                    
                    if (byteLen == 1)
                        mDataBit = recvCmd[readbit];
                    else{

                        return -1;
                    }
                    readbit+=(byteLen+1);

                }else if (recvCmd[readbit] == 0x04) { //parity
                    int byteLen = recvCmd[++readbit];
                    readbit++;
                    
                    if (byteLen == 1)
                        mParityBit = recvCmd[readbit];
                    else{

                        return -1;
                    }
                    readbit+=(byteLen+1);

                }else if (recvCmd[readbit] == 0x08) { //stopbit
                    int byteLen = recvCmd[++readbit];
                    readbit++;
                    
                    if (byteLen == 1)
                        mStopBit = recvCmd[readbit];
                    else{

                        return -1;
                    }
                    readbit+=(byteLen+1);

                }else
                    readbit++;
            }while (readbit < [message length]);

            return 1;//update UI
        }//if (recvCmd[readbit] == 0x01)
        

        
    }
    return 2;//other
}

- (Boolean) checkPrefix:(uint8_t *) recvPrefix
{
    for (int i = 0; i < sizeof(mCmdPrefix); i++) {
        if(recvPrefix[i] != mCmdPrefix[i])
            return false;
    }
    return true;
}

#pragma mark -
#pragma mark NSNetServiceBrowserDelegate methods
-(void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict {

    self.netServiceBrowser.delegate = nil;
    [self.netServiceBrowser stop];
    self.netServiceBrowser = nil;
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {

    self.netServiceBrowser.delegate = nil;
    self.netServiceBrowser = nil;
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    
    
    [self.controlServicesArray addObject:aNetService];
    
    aNetService.delegate = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        [aNetService resolveWithTimeout:5.0];
    });
    
   
    
    if (moreComing == NO) {
    
        
        
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
        [self.controlServicesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
    
        [self.netServiceBrowser stop];
        self.netServiceBrowser.delegate = nil;
        self.netServiceBrowser  = nil;

        [self.collectionView reloadData];
        isFindServiceDone = true;
    }
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
    for (int i = 0; i < self.controlServicesArray.count; i++) {
        if ([((NSNetService *)[self.controlServicesArray objectAtIndex:i]).name isEqualToString:netService.name]) {
            [self.controlServicesArray removeObjectAtIndex:i];
            break;
        }
    }
    if (moreComing == NO) {
        [self.collectionView reloadData];
        
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
        [self.controlServicesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
      
    }
}

#pragma mark -
#pragma mark NSNetServiceDelegate methods
-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSNumber *errorCode = [errorDict valueForKey:NSNetServicesErrorCode];
    
    NSString *errorMessage;
    switch ([errorCode intValue]) {
        case NSNetServicesActivityInProgress:
            errorMessage = @"Service Resolution Currently in Progress. Please Wait.";
            break;
        case NSNetServicesTimeoutError:
            errorMessage = @"Service Resolution Timeout";
          
      
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                [sender resolveWithTimeout:5.0];
            });
            break;
    }
    
    
    //[alert release];
}

-(void)netServiceDidResolveAddress:(NSNetService *)service {
   
    NSString *textRecord;
    static struct _IOTInfo IOTInfo;
    struct _IOTInfo tmpIOTInfo;
    
    /*
     if(self.netServiceBrowser == nil)
     return;
     */
    
    for (int i = 0 ; i < self.controlServicesArray.count; i++) {
        if ([service.name isEqualToString:[[self.controlServicesArray objectAtIndex:i] name]]) {
            [self.controlServicesArray replaceObjectAtIndex:i withObject:service];
           
        }
    }
    
    textRecord = [[NSString alloc]initWithData:[service TXTRecordData] encoding:NSUTF8StringEncoding];
    IOTInfo.groupID = [[textRecord substringWithRange:NSMakeRange([textRecord rangeOfString:@"groupid:"].location + 8,[textRecord rangeOfString:@", tcpserver:"].location - [textRecord rangeOfString:@"groupid:"].location - 8 )] integerValue];
    
    
    IOTInfo.service = service;
    if(IOTInfo.groupID != 0)
        IOTInfo.groupName = IOTInfo.service.name;
    [_IOTInfoArray addObject:[NSValue valueWithBytes:&IOTInfo objCType:@encode(struct _IOTInfo)]];

    
     for (int i=0; i < IOTItemListArray.count ; i++) {
         [[IOTItemListArray objectAtIndex:i] getValue:&tmpIOTInfo];
         
         if ( IOTInfo.groupID != 0 && tmpIOTInfo.groupID == IOTInfo.groupID ){

             
             
             
             return;
         }else if( [[tmpIOTInfo.service name] isEqualToString:[service name] ]){
             return;
         
         }
         
     }
    [IOTItemListArray addObject:[NSValue valueWithBytes:&IOTInfo objCType:@encode(struct _IOTInfo)]];
    [self.collectionView reloadData];

    
}

// the user tapped a collection item, load and set the image on the detail view controller
//

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    isFindServiceDone = FALSE;
    
    
    if ([segue.identifier isEqualToString:@"showDetail"])
    {
       
        
        ChatViewController *chatVC = segue.destinationViewController;
       
        NSIndexPath *cvindex= [self.collectionView indexPathsForSelectedItems][0];
        chatVC.selectedService = self.selectedService;//self.controlServicesArray[cvindex.row ];
       
       
    }else if ([segue.identifier isEqualToString:@"showSetting"])
    {
       
        
        struct _IOTInfo IOTDevice;
        [[IOTItemListArray objectAtIndex:longPressIndexPath.row] getValue:&IOTDevice];

        [SettingPageViewController initSettingIOTInfoArray];
        SettingPageViewController *settingVC =  segue.destinationViewController;
        settingVC.allSettings = output;
        
        settingVC.selectedGroupID = IOTDevice.groupID;
        
        if (IOTDevice.groupID == 0) {
       
            settingVC.selectedService = IOTDevice.service;
        }else{
        
            for (int i = 0; i < _IOTInfoArray.count; i++) {
                [[_IOTInfoArray objectAtIndex:i] getValue:&IOTDevice];
                if (IOTDevice.groupID == settingVC.selectedGroupID) {                                    
                    [SettingPageViewController copyIOTInfo:IOTDevice.service];
                }
            }
        }
        


    }

}

- (void)viewDidUnload {
    [super viewDidUnload];
    [inputStream close];
    [outputStream close];
    self.netServiceBrowser.delegate = nil;
    [self.netServiceBrowser stop];
    self.netServiceBrowser  = nil;
   // IOTInfoArray = nil;
    IOTItemListArray = nil;
}

- (void)dealloc
{
    [inputStream close];
    [outputStream close];
    self.netServiceBrowser = nil;
    self.controlServicesArray = nil;
    self.selectedService = nil;
    //IOTInfoArray = nil;
    IOTItemListArray = nil;
    //[super dealloc];
}


@end
