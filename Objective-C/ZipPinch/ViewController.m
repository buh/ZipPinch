//
//  ViewController.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 NARR8. All rights reserved.
//

#import "ViewController.h"
#import "ZPManager.h"

static NSString *const ViewControllerEntriesSegue = @"entriesSegue";
static NSString *const ViewControllerImageSegue = @"imageSegue";

@interface ViewController () <UINavigationControllerDelegate, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic) BOOL cacheEnabled;
@property (nonatomic) ZPManager *zipManager;
@property (nonatomic) ZPEntry *selectedImageEntry;
@property (nonatomic, weak) UITableViewController *tableViewController;
@property (nonatomic) UIImageView *imageView;
@property (nonatomic) NSByteCountFormatter *byteFormatter;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _cacheEnabled = YES;
    _byteFormatter = [NSByteCountFormatter new];
    
    self.navigationController.delegate = self;
    self.textField.delegate = self;
}

- (IBAction)finishEditingTextField:(UITextField *)sender
{
    if (sender.text.length) {
        if (![sender.text hasPrefix:@"http"]) {
            sender.text = [@"http://" stringByAppendingString:sender.text];
        }
        
        NSURL *URL = [NSURL URLWithString:sender.text];
        
        if (URL && URL.host && [URL.host rangeOfString:@"."].location != NSNotFound) {
            [_activityIndicator startAnimating];
            [self loadZipWithURL:URL];
            
            return;
        }
    }
    
    [self alertWithErrorMessage:@"URL not valid"];
}

- (IBAction)showHubblePhotos:(UIButton *)sender
{
    _textField.text = @"http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip";
    [self finishEditingTextField:_textField];
}

- (IBAction)updateCacheEnabled:(UISwitch *)sender
{
    _cacheEnabled = sender.on;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self cancelZipLoading];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return NO;
}

- (void)cancelZipLoading
{
    [_activityIndicator stopAnimating];
    _zipManager = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:ViewControllerEntriesSegue]) {
        _tableViewController = segue.destinationViewController;
        _tableViewController.tableView.dataSource = self;
        _tableViewController.tableView.delegate = self;
        _tableViewController.title = _zipManager.URL.host;
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (_selectedImageEntry && viewController != self && viewController != _tableViewController) {
        _imageView = nil;
        
        [viewController.view.subviews enumerateObjectsUsingBlock:^(UIImageView *imageView, NSUInteger idx, BOOL *stop) {
            if ([imageView isKindOfClass:[UIImageView class]]) {
                _imageView = imageView;
                *stop = YES;
            }
        }];
        
        if (_imageView) {
            [_zipManager loadDataWithFilePath:_selectedImageEntry.filePath completionBlock:^(NSData *data, NSError *error) {
                if (error) {
                    [self alertError:error];
                } else {
                    _imageView.image = [[UIImage alloc] initWithData:data];
                }
            }];
        }
        
    } else if (viewController == self) {
        _imageView = nil;
        _tableViewController = nil;
        _selectedImageEntry = nil;
        _zipManager = nil;
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _zipManager.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellId = @"cellId";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    
    ZPEntry *entry = _zipManager.entries[indexPath.row];
    
    cell.textLabel.text = entry.filePath;
    cell.detailTextLabel.text = [_byteFormatter stringFromByteCount:entry.sizeCompressed];
    cell.accessoryType = ([self isImageWithFileName:entry.filePath]
                          ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone);
    
    return cell;
}

- (BOOL)isImageWithFileName:(NSString *)fileName
{
    NSString *extension = [[fileName pathExtension] lowercaseString];
    
    return [extension isEqual:@"jpg"] || [extension isEqual:@"png"] || [extension isEqual:@"gif"] || [extension isEqual:@"jpeg"];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ZPEntry *entry = _zipManager.entries[indexPath.row];
    
    return [self isImageWithFileName:entry.filePath] ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _selectedImageEntry = _zipManager.entries[indexPath.row];
    [_tableViewController performSegueWithIdentifier:ViewControllerImageSegue sender:nil];
}

#pragma mark - ZipPinch

- (void)loadZipWithURL:(NSURL *)URL
{
    _zipManager = [[ZPManager alloc] initWithURL:URL];
    
    if (_cacheEnabled) {
        [_zipManager enableCacheAtPath:nil];
    }
    
    __weak ZPManager *zipManager = _zipManager;
    __weak ViewController *weakSelf = self;
    
    [_zipManager loadContentWithCompletionBlock:^(long long fileLength, NSArray *entries, NSError *error) {
        if (error) {
            [weakSelf.activityIndicator stopAnimating];
            [weakSelf alertError:error];
            
            return;
        }
        
        if (weakSelf.zipManager && zipManager == weakSelf.zipManager) {
            if (entries.count) {
                [weakSelf.activityIndicator stopAnimating];
                [weakSelf performSegueWithIdentifier:ViewControllerEntriesSegue sender:nil];
                
            } else {
                [weakSelf cancelZipLoading];
                [weakSelf alertWithErrorMessage:@"Zip empty or not found"];
            }
        }
    }];
}

#pragma mark - Alert

- (void)alertError:(NSError *)error
{
    [self alertWithErrorMessage:[error localizedDescription]];
}

- (void)alertWithErrorMessage:(NSString *)message
{
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:message
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
