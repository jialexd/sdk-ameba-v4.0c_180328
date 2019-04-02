//
//  SettingPageViewController.h
//  uartadapter
//
//  Created by isaiah on 9/1/15.
//  Copyright (c) 2015 realtek. All rights reserved.
//


#import <UIKit/UIKit.h>

@interface SettingPageViewController : UIViewController<
UIPickerViewDataSource,
UIPickerViewDelegate,
UITextFieldDelegate,
NSStreamDelegate,
NSNetServiceBrowserDelegate,
NSNetServiceDelegate,
UIAlertViewDelegate>
{

}

+ (void) initSettingIOTInfoArray;
+ (void) copyIOTInfo:(NSNetService *)mService;

@property (nonatomic, retain) NSData *allSettings;
@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
//@property (nonatomic, retain) NSMutableArray *settingIOTInfoArray;
@property (nonatomic, retain) NSNetService *selectedService;
@property (nonatomic, assign) NSInteger  selectedGroupID;
@property (nonatomic, retain) IBOutlet UITextField	*baudRateField;
@property (nonatomic, retain) IBOutlet UITextField	*dataBitField;
@property (nonatomic, retain) IBOutlet UITextField	*parityBitField;
@property (nonatomic, retain) IBOutlet UITextField	*stopBitField;
//@property (nonatomic, retain) IBOutlet UIPickerView *datapicker;

- (IBAction) saveSettings;
- (IBAction) restoreSettings;

@end




