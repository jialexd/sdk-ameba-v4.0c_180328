//
//  SettingPageViewController.m
//  uartadapter
//
//  Created by isaiah on 9/1/15.
//  Copyright (c) 2015 realtek. All rights reserved.
//

//#import <Foundation/Foundation.h>
#import "ViewController.h"
#import "SettingPageViewController.h"
#include <ifaddrs.h>
#include <arpa/inet.h>


uint8_t const cmdPrefix[] = { 0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54 };;
uint8_t const cmdGetAllSetting[] = { 0x02, 0x00, 0x0f };

NSMutableArray *settingIOTInfoArray;

@interface SettingPageViewController ()

@end



@implementation SettingPageViewController


@synthesize inputStream, outputStream;
@synthesize selectedService = _selectedService;
@synthesize baudRateField, dataBitField, parityBitField, stopBitField;
@synthesize allSettings = _allSettings;
//@synthesize datapicker;


//UIAlertView *alert;

NSArray * baurateData ;
NSArray * bitData;
NSArray * parityBitData;
NSArray * stopBitdata;

int mBardRate = 0;
int mDataBit = 0;
int mParityBit = 0;
int mStopBit = 0;


UIPickerView *datapicker;
int mTextFieldTag = -1;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]];
    
    
    baurateData = [[NSArray alloc] initWithObjects:@"1200", @"9600", @"14400", @"19200", @"28800", @"38400", @"57600", @"76800", @"115200", @"128000", @"153600", @"230400", @"460800", @"500000", @"921600", nil];
    bitData = [[NSArray alloc] initWithObjects:@"7", @"8", nil];
    parityBitData = [[NSArray alloc] initWithObjects:@"none", @"odd", @"even", nil];
    stopBitdata = [[NSArray alloc] initWithObjects:@"none", @"1", nil];
    
    datapicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 50, 100, 150)];
    [datapicker setDataSource: self];
    [datapicker setDelegate: self];
    [baudRateField setDelegate:self];
    [dataBitField setDelegate:self];
    [parityBitField setDelegate:self];
    [stopBitField setDelegate:self];
    
    datapicker.showsSelectionIndicator = YES;

    self.baudRateField.inputView = datapicker;
    self.dataBitField.inputView = datapicker;
    self.parityBitField.inputView = datapicker;
    self.stopBitField.inputView = datapicker;
    
    if([self inputStreamReceivedParser:self.allSettings] == 1)//update ui
    {
        self.baudRateField.text = [NSString stringWithFormat:@"%d",mBardRate];
        
        self.dataBitField.text = [NSString stringWithFormat:@"%d",mDataBit];
        
        if (mParityBit == 0)
            self.parityBitField.text = @"none";
        else if (mParityBit == 1)
            self.parityBitField.text = @"odd";
        else if (mParityBit == 2)
            self.parityBitField.text = @"even";
        
        if (mStopBit == 0)
            self.stopBitField.text = @"none";
        else if (mStopBit == 1)
            self.stopBitField.text = @"1";
        
        //                   [alert dismissWithClickedButtonIndex:0 animated:YES];
        
    }
    
    //[self prepareForInitNetworkCommunication];
    /*
    alert = [[UIAlertView alloc] initWithTitle:@"UART Adapter" message:@"Connecting" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
    UIActivityIndicatorView * alertIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(125.0, 00.0, 30.0, 30.0) ];
    alertIndicator.activityIndicatorViewStyle =  UIActivityIndicatorViewStyleWhiteLarge;
    //alertIndicator.center = CGPointMake(alert.bounds.size.width/2 , (alert.bounds.size.height/2) + 10);
    
    [alertIndicator startAnimating];
   
    if ([[[UIDevice currentDevice] systemVersion]compare:@"7.0"] != NSOrderedAscending)
        [alert setValue:alertIndicator forKey:@"accessoryView"];
    else
        [alert addSubview:alertIndicator];
  //  [alert show];
    */
    /*
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self queryAllSettings];
    });
     */
    
    
}



- (IBAction) restoreSettings
{
    self.baudRateField.text = [NSString stringWithFormat:@"%d",mBardRate];
    self.dataBitField.text = [NSString stringWithFormat:@"%d",mDataBit];
    
    if (mParityBit == 0)
        self.parityBitField.text = @"none";
    else if (mParityBit == 1)
        self.parityBitField.text = @"odd";
    else if (mParityBit == 2)
        self.parityBitField.text = @"even";
    
    if (mStopBit == 0)
        self.stopBitField.text = @"none";
    else if (mStopBit == 1)
        self.stopBitField.text = @"1";
    [datapicker reloadAllComponents];
}

- (IBAction) saveSettings{
    
    NSString * stringTxtField;
    uint8_t cmdReq[] = {0x00};
    uint8_t *cmdBaudrate = NULL;
    uint8_t *cmdDatabit = NULL;
    uint8_t *cmdParity = NULL;
    uint8_t *cmdStopbit = NULL;
    
    
    stringTxtField = self.baudRateField.text;
    
    if([stringTxtField isEqualToString:@"1200"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0xB0, 0x04, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"9600"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x80, 0x25, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"14400"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x40, 0x38, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"19200"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x4B, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"28800"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x80, 0x70, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"38400"]){
        cmdBaudrate = (uint8_t []){ 0x00, 0x01, 0x04, 0x00, 0x96, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"57600"]){
        cmdBaudrate = (uint8_t []){ 0x00, 0x01, 0x04, 0x00, 0xE1, 0x00, 0x00 };
    }else if([stringTxtField isEqualToString:@"76800"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x2C, 0x01, 0x00 };
    }else if([stringTxtField isEqualToString:@"115200"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0xC2, 0x01, 0x00 };
    }else if([stringTxtField isEqualToString:@"128000"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0xF4, 0x01, 0x00 };
    }else if([stringTxtField isEqualToString:@"153600"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x58, 0x02, 0x00 };
    }else if([stringTxtField isEqualToString:@"230400"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x84, 0x03, 0x00 };
    }else if([stringTxtField isEqualToString:@"460800"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x08, 0x07, 0x00 };
    }else if([stringTxtField isEqualToString:@"500000"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x20, 0xA1, 0x07, 0x00 };
    }else if([stringTxtField isEqualToString:@"921600"]){
        cmdBaudrate = (uint8_t []) { 0x00, 0x01, 0x04, 0x00, 0x10, 0x0E, 0x00 };
    }

    stringTxtField = self.dataBitField.text;
    if([stringTxtField isEqualToString:@"8"]){
        cmdDatabit = (uint8_t []) { 0x00, 0x02, 0x01, 0x08 };
    }else{
        cmdDatabit = (uint8_t []) { 0x00, 0x02, 0x01, 0x07 };
    }
    
    stringTxtField = self.parityBitField.text;
    if([stringTxtField isEqualToString:@"none"]){
        cmdParity = (uint8_t []) { 0x00, 0x04, 0x01, 0x00 };
    }else if([stringTxtField isEqualToString:@"odd"]){
        cmdParity = (uint8_t []) { 0x00, 0x04, 0x01, 0x01 };
    }else if([stringTxtField isEqualToString:@"even"]){
        cmdParity = (uint8_t []) { 0x00, 0x04, 0x01, 0x02 };
    }
    
    stringTxtField = self.stopBitField.text;
    if([stringTxtField isEqualToString:@"none"]){
        cmdStopbit = (uint8_t []) { 0x00, 0x08, 0x01, 0x00 };
    }else if([stringTxtField isEqualToString:@"1"]){
        cmdStopbit = (uint8_t []) { 0x00, 0x08, 0x01, 0x01 };
    }

    
    NSMutableData *cmdSetSettings = [[NSMutableData alloc] initWithBytes:cmdPrefix length:sizeof(cmdPrefix)];
    [cmdSetSettings appendBytes:cmdReq length:1];
    [cmdSetSettings appendBytes:cmdBaudrate length:7];
    [cmdSetSettings appendBytes:cmdDatabit length:4];
    [cmdSetSettings appendBytes:cmdParity  length:4];
    [cmdSetSettings appendBytes:cmdStopbit  length:4];
    


    
    if (self.selectedGroupID != 0) {

        for (int i=0 ; i < settingIOTInfoArray.count; i++) {
            NSNetService * groupIOTDevice = [settingIOTInfoArray objectAtIndex:i];
            
            
            
            [self prepareForInitNetworkCommunication:[groupIOTDevice.addresses objectAtIndex:0 ] Port:(int)groupIOTDevice.port];
            [outputStream write:[cmdSetSettings bytes] maxLength:[cmdSetSettings length]];
            
        }

    }else{
        
        [self prepareForInitNetworkCommunication:[self.selectedService.addresses objectAtIndex:0 ] Port:(int)self.selectedService.port];
        [outputStream write:[cmdSetSettings bytes] maxLength:[cmdSetSettings length]];
    
    }
    
}

+ (void) initSettingIOTInfoArray
{
    settingIOTInfoArray = [[NSMutableArray alloc] init];
}

+ (void) copyIOTInfo:(NSNetService *)mService
{
    
    
    [settingIOTInfoArray addObject:mService];
   // struct _IOTInfo IOTInfo;
    //settingIOTInfoArray = [[NSMutableArray alloc] init];
  
   // for (int i = 0; i < mIOTInfoArray.count; i++) {
      //  [[mIOTInfoArray objectAtIndex:i] getValue:&IOTInfo];

       // [settingIOTInfoArray addObject:[NSValue valueWithBytes:&IOTInfo objCType:@encode(struct _IOTInfo)]];
   //}
    
}

- (void) queryAllSettings {
    
    NSMutableData *cmd = [[NSMutableData alloc] initWithBytes:cmdPrefix length:sizeof(cmdPrefix)];
    [cmd appendBytes:cmdGetAllSetting length:sizeof(cmdGetAllSetting)];
    [outputStream write:[cmd bytes] maxLength:[cmd length]];
    
}



- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    

    
    switch (streamEvent) {
            
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable:
            
            if (theStream == inputStream) {
                
                uint8_t buffer[64] = {0};
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [[NSNumber numberWithInteger:[inputStream read:buffer maxLength: sizeof(buffer)]] intValue] ;
                    if (len > 0) {
                        
                        NSData *output = [[NSData alloc] initWithBytes:buffer length:len];

                        
                        if (nil != output) {
                            

                            if([self inputStreamReceivedParser:output] == 1)//update ui
                            {
                                self.baudRateField.text = [NSString stringWithFormat:@"%d",mBardRate];
                                
                                self.dataBitField.text = [NSString stringWithFormat:@"%d",mDataBit];
                                
                                if (mParityBit == 0)
                                    self.parityBitField.text = @"none";
                                else if (mParityBit == 1)
                                    self.parityBitField.text = @"odd";
                                else if (mParityBit == 2)
                                    self.parityBitField.text = @"even";
                                
                                if (mStopBit == 0)
                                    self.stopBitField.text = @"none";
                                else if (mStopBit == 1)
                                    self.stopBitField.text = @"1";
                                
         
                              

                                
                            }
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Serial Port Setup" message:@"Success!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [alert show];
                            
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

- (int) inputStreamReceivedParser:(NSData *)message {
    
    uint8_t *recvCmd = (uint8_t *)[message bytes] ;
   
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
    for (int i = 0; i < sizeof(cmdPrefix); i++) {
        if(recvPrefix[i] != cmdPrefix[i])
            return false;
    }
    return true;
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

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    mTextFieldTag = (int)textField.tag;

    [datapicker reloadAllComponents];

}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    switch (mTextFieldTag) {
        case 0:
            self.baudRateField.text = baurateData[row];
            break;
        case 1:
            self.dataBitField.text = bitData[row];
            break;
        case 2:
            self.parityBitField.text = parityBitData[row];
            break;
        case 3:
            self.stopBitField.text = stopBitdata[row];
            break;
        default:
            break;
    }
    
    [[self view] endEditing:YES];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    
    switch (mTextFieldTag) {
        case 0:
            return baurateData[row];
            break;
        case 1:
            return bitData[row];
            break;
        case 2:
            return parityBitData[row];
            break;
        case 3:
            return stopBitdata[row];
            break;
        default:
            return 0;
            break;
    }
    
    
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return  1 ;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    switch (mTextFieldTag) {
        case 0:
            return baurateData.count;
            break;
        case 1:
            return bitData.count;
            break;
        case 2:
            return parityBitData.count;
            break;
        case 3:
            return stopBitdata.count;
            break;
        default:
            return 0;
            break;
    }
    
}


- (void)viewDidUnload {
     [super viewDidUnload];
     settingIOTInfoArray = nil;
}

- (void)dealloc
{
    [inputStream close];
    [outputStream close];
    self.selectedService = nil;
    settingIOTInfoArray = nil;
}

@end