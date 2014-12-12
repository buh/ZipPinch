//
//  ViewController.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 NARR8. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

- (IBAction)finishEditingTextField:(UITextField *)sender;
- (IBAction)showHubblePhotos:(UIButton *)sender;
- (IBAction)updateCacheEnabled:(UISwitch *)sender;

@end

