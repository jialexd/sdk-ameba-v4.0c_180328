/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The secondary detailed view controller for this app.
*/


#import "ChatViewController.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface ChatViewController ()

@end

@implementation ChatViewController

@synthesize inputStream, outputStream;
@synthesize inputMessageField,chatMessageField;
@synthesize selectedService = _selectedService;
@synthesize messages;

NSString *UART_DATA_TYPE=@"_uart_data._tcp.local.";
NSDateFormatter *formatter;
NSString        *timeString;
NSMutableAttributedString *attrMessage;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [[UIImage imageNamed:@"background.png"] drawInRect:self.view.bounds];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

 
    self.chatMessageField.contentMode = UIViewContentModeScaleToFill;
    self.chatMessageField.backgroundColor=[UIColor colorWithPatternImage:bgImage];
    

    
    self.dataServicesArray = [[NSMutableArray alloc] init];
    [self startDiscover:UART_DATA_TYPE];
 
    
    self.inputMessageField.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:@"UIKeyboardWillShowNotification"
                                                   object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardDidHide:)
                                                     name:@"UIKeyboardWillHideNotification"
                                                   object:nil];
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm"];
    
    
    NSAttributedString *objectString =
    [[NSAttributedString alloc] initWithString:@""
                                    attributes:@{
                                                 NSForegroundColorAttributeName : [UIColor redColor],
                                                 NSFontAttributeName : [UIFont boldSystemFontOfSize:20]
                                                 }];
    
    attrMessage = [[NSMutableAttributedString alloc] initWithAttributedString:objectString];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void) keyboardWillShow:(NSNotification *)note {
    NSDictionary *userInfo = [note userInfo];
    CGSize kbSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    
    
    // move the view up by 30 pts
    CGRect frame = self.view.frame;
    frame.origin.y = -kbSize.height;
    
    [UIView animateWithDuration:0.01 animations:^{
        self.view.frame = frame;
    }];
}

- (void) keyboardDidHide:(NSNotification *)note {
    
    // move the view back to the origin
    CGRect frame = self.view.frame;
    frame.origin.y = 0;
    self.view.frame = frame;
   
}

-(void) startDiscover:(NSString *)browseType
{
    self->_netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    self->_netServiceBrowser.delegate = self;
    
    NSArray *domainNameParts = [browseType componentsSeparatedByString:@"."];
    
    browseType = [NSString stringWithFormat:@"%@.%@.", [domainNameParts objectAtIndex:0], [domainNameParts objectAtIndex:1]];
  
    [self->_netServiceBrowser searchForServicesOfType:browseType inDomain:@""];
}


-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    
    [self.dataServicesArray addObject:aNetService];
    
    
    
    if (moreComing == NO) {
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
        [self.dataServicesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
        //[sd release];
        
        self->_netServiceBrowser.delegate = nil;
        [self->_netServiceBrowser stop];
        self->_netServiceBrowser  = nil;
        self.title = self.selectedService.name;
    }
    
    if([self.selectedService.name isEqualToString:aNetService.name])
    {
         aNetService.delegate = self;
        [aNetService resolveWithTimeout:10.0];
    }
}


-(void)netServiceDidResolveAddress:(NSNetService *)service {
    
    NSData *address = [service.addresses objectAtIndex:0];
    char addressString[INET6_ADDRSTRLEN];
    int inetType;
    
    struct sockaddr_in6 addr6;
    memcpy(&addr6, address.bytes, address.length);
    
    if (address.length == 16) { // IPv4
        inetType = AF_INET;
        struct sockaddr_in addr4;
        memcpy(&addr4, address.bytes, address.length);
        inet_ntop(AF_INET, &addr4.sin_addr, addressString, 512);
        [self initNetworkCommunication:[NSString stringWithCString:addressString encoding:NSASCIIStringEncoding] Port:(int)service.port];
        
    }

    
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
    for (int i = 0; i < self.dataServicesArray.count; i++) {
        if ([((NSNetService *)[self.dataServicesArray objectAtIndex:i]).name isEqualToString:netService.name]) {
            [self.dataServicesArray removeObjectAtIndex:i];
            break;
        }
    }
    if (moreComing == NO) {
      
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
        [self.dataServicesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
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
            [sender stop];
            //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bonjour Browser" message:errorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
           // [alert show];
            break;
    }
    
    
    //[alert release];
}

#pragma mark -
#pragma mark NSNetServiceBrowserDelegate methods
-(void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict {
    self->_netServiceBrowser.delegate = nil;
    [self->_netServiceBrowser stop];
    self->_netServiceBrowser = nil;
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {
    self->_netServiceBrowser.delegate = nil;
    self->_netServiceBrowser = nil;
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


- (IBAction) sendMessage {
    NSAttributedString *sendingString;
    
    timeString = [formatter stringFromDate:[NSDate date]];

    NSString *response  =  [NSString stringWithFormat:@"%@\n", inputMessageField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    response  =  [NSString stringWithFormat:@"%@ [Me] %@\n",timeString, inputMessageField.text];
    sendingString =
    [[NSAttributedString alloc] initWithString:response
                                    attributes:@{
                                                 NSForegroundColorAttributeName : [UIColor blueColor],
                                                 NSFontAttributeName : [UIFont boldSystemFontOfSize:20]
                                                 }];
    inputMessageField.text = @"";
    [attrMessage appendAttributedString:sendingString];
    [chatMessageField setAttributedText:attrMessage];
    [inputMessageField resignFirstResponder];
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    

    
    switch (streamEvent) {
            
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable:
            
            if (theStream == inputStream) {
                
                uint8_t buffer[1024];
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [[NSNumber numberWithInteger:[inputStream read:buffer maxLength: sizeof(buffer)]] intValue] ;
                    if (len > 0) {
                        
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        
                        if (nil != output) {
                            

                            [self messageReceived:output];
                            
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
            //[theStream release];
            theStream = nil;
            
            break;
        default:
            NSLog(@"Unknown event");
    }
    
}

- (void) messageReceived:(NSString *)message {
    
    NSAttributedString *receivedString;
        
    [self.chatMessageField setTintColor:[UIColor greenColor]];
    timeString = [formatter stringFromDate:[NSDate date]];
    receivedString =
    [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ [Ameba] %@\n", timeString ,message]
                                    attributes:@{
                                                 NSForegroundColorAttributeName : [UIColor purpleColor],
                                                 NSFontAttributeName : [UIFont boldSystemFontOfSize:20]
                                                 }];
    
    [attrMessage appendAttributedString:receivedString];
    [chatMessageField setAttributedText:attrMessage];
}




- (void)viewDidUnload {
    [super viewDidUnload];
    
    self->_netServiceBrowser.delegate = nil;
    [self->_netServiceBrowser stop];
    self->_netServiceBrowser  = nil;
}

- (void)dealloc
{
     [[NSNotificationCenter defaultCenter] removeObserver:self];
    [inputStream close];
    [outputStream close];
    self->_netServiceBrowser = nil;
    self.dataServicesArray = nil;
    self.selectedService = nil;
}


@end
