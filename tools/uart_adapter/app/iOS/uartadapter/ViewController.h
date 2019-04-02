//
//  ViewController.h
//  uartadapter
//
//  Created by isaiah on 8/26/15.
//  Copyright (c) 2015 realtek. All rights reserved.
//

#import <UIKit/UIKit.h>

struct _IOTInfo {
    __unsafe_unretained NSNetService  *service;
    __unsafe_unretained NSString *groupName;
    NSInteger groupID;
    
};

@interface ViewController : UICollectionViewController < /*UICollectionViewDelegateFlowLayout*/ NSNetServiceBrowserDelegate,
NSNetServiceDelegate,
UIAlertViewDelegate,
NSStreamDelegate,
NSNetServiceBrowserDelegate,
NSNetServiceDelegate,
UIGestureRecognizerDelegate> {
    NSNetServiceBrowser *_netServiceBrowser;
    NSMutableArray *_servicesArray;
    NSNetService *_selectedService;
}


@property (nonatomic, retain) NSMutableArray *IOTInfoArray;
@property (nonatomic, retain) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, retain) NSMutableArray *controlServicesArray;
@property (nonatomic, retain) NSMutableArray *dataServicesArray;
@property (nonatomic, retain) NSNetService *selectedService;

- (IBAction) scanButton;

@end

