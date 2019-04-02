/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The secondary detailed view controller for this app.
*/

#import <UIKit/UIKit.h>

@interface ChatViewController : UIViewController <NSStreamDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, UITextFieldDelegate>
{
    NSNetServiceBrowser *_netServiceBrowser;
    NSMutableArray *_servicesArray;
    
    NSMutableArray	*messages;
    NSInputStream	*inputStream;
    NSOutputStream	*outputStream;
}

@property (nonatomic, retain) NSNetService *selectedService;
@property (nonatomic, retain) NSMutableArray *dataServicesArray;


@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic, retain) NSMutableArray *messages;

- (IBAction) sendMessage;
@property (nonatomic, retain) IBOutlet UITextView  *chatMessageField;
@property (nonatomic, retain) IBOutlet UITextField	*inputMessageField;
@end
