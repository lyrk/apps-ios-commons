//
//  DetailTableViewController.m
//  Commons-iOS
//
//  Created by Brion on 1/29/13.
//  Copyright (c) 2013 Wikimedia. All rights reserved.
//

#import "DetailTableViewController.h"
#import "CommonsApp.h"
#import "WebViewController.h"
#import "ImageScrollViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "MWI18N/MWMessage.h"
#import "MyUploadsViewController.h"

@interface DetailTableViewController ()

@end

@implementation DetailTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

/**
 * View has loaded.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // l10n
    self.title = [MWMessage forKey:@"details-title"].text;
    self.uploadButton.title = [MWMessage forKey:@"details-upload-button"].text;
    self.titleLabel.text = [MWMessage forKey:@"details-title-label"].text;
    self.titleTextField.placeholder = [MWMessage forKey:@"details-title-placeholder"].text;
    self.descriptionLabel.text = [MWMessage forKey:@"details-description-label"].text;
    self.descriptionPlaceholder.text = [MWMessage forKey:@"details-description-placeholder"].text;
    self.licenseLabel.text = [MWMessage forKey:@"details-license-label"].text;

    // Load up the selected record
    FileUpload *record = self.selectedRecord;
    
    if (record != nil) {
        self.titleTextField.text = record.title;
        self.descriptionTextView.text = record.desc;
        self.descriptionPlaceholder.hidden = (record.desc.length > 0);
        self.imageSpinner.hidden = NO;

        MWPromise *thumb = [record fetchThumbnail];
        [thumb done:^(UIImage *image) {
            self.imageSpinner.hidden = YES;
            self.imagePreview.image = image;
        }];
        [thumb fail:^(NSError *error) {
            NSLog(@"Failed to fetch wiki image: %@", [error localizedDescription]);
            self.imageSpinner.hidden = YES;
        }];

        if (record.complete.boolValue) {
            // Completed upload...
            self.titleTextField.enabled = NO;
            self.descriptionTextView.editable = NO;
            self.deleteButton.enabled = NO; // fixme in future, support deleting uploaded items
            self.actionButton.enabled = YES; // open link or share on the web
            self.uploadButton.enabled = NO; // fixme either hide or replace with action button?
            
            // fixme: load description from wiki page
            self.descriptionLabel.hidden = YES;
            self.descriptionTextView.hidden = YES;
            self.descriptionPlaceholder.hidden = YES;

            // fixme: load license info from wiki page
            self.licenseLabel.hidden = YES;
            self.licenseNameLabel.hidden = YES;
            self.ccByImage.hidden = YES;
            self.ccSaImage.hidden = YES;

            // either use HTML http://commons.wikimedia.org/wiki/Commons:Machine-readable_data
            // or pick apart the standard templates
        } else {
            // Locally queued file...
            self.titleTextField.enabled = YES;
            self.descriptionTextView.editable = YES;
            self.deleteButton.enabled = (record.progress.floatValue == 0.0f); // don't allow delete _during_ upload
            self.actionButton.enabled = NO;

            self.descriptionLabel.hidden = NO;
            self.descriptionTextView.hidden = NO;
            self.descriptionPlaceholder.hidden = (record.desc.length > 0);
            self.licenseLabel.hidden = NO;
            self.licenseNameLabel.hidden = NO;
            self.ccByImage.hidden = NO;
            self.ccSaImage.hidden = NO;

            [self updateUploadButton];
        }
    } else {
        NSLog(@"This isn't right, have no selected record in detail view");
    }

    // Set delegates so we know when fields change...
    self.titleTextField.delegate = self;
    self.descriptionTextView.delegate = self;
}

- (void)updateUploadButton
{
    FileUpload *record = self.selectedRecord;
    if (record != nil && !record.complete.boolValue) {
        self.uploadButton.enabled = record.title.length > 0 &&
                                    record.desc.length > 0;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

// hack to hide table cells
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.item >= 2 && self.selectedRecord && self.selectedRecord.complete.boolValue) {
        // fixme: when we extract description and license for done files, stop hiding
        return 0;
    }
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}


#pragma mark -

- (void)popViewControllerAnimated {
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"OpenPageSegue"]) {
        if (self.selectedRecord) {
            WebViewController *view = [segue destinationViewController];
            NSString *pageTitle = [@"File:" stringByAppendingString:self.selectedRecord.title];
            view.targetURL = [CommonsApp.singleton URLForWikiPage:pageTitle];
        }
    } else if ([segue.identifier isEqualToString:@"OpenLicenseSegue"]) {
        WebViewController *view = [segue destinationViewController];
        // fixme use the proper link for data
        view.targetURL = [NSURL URLWithString:@"https://creativecommons.org/licenses/by-sa/3.0/"];
    } else if ([segue.identifier isEqualToString:@"OpenImageSegue"]) {
        
        if (self.selectedRecord) {
            
            ImageScrollViewController *view = [segue destinationViewController];
            
            CGFloat density = [UIScreen mainScreen].scale;
            CGSize size = CGSizeMake(1024.0f * density, 1024.0f * density);
            
            FileUpload *record = self.selectedRecord;
            if (record != nil) {
                
                view.title = record.title;
                
                MWPromise *fetch;
                if (record.complete.boolValue) {
                    // Fetch cached or internet image at standard size...
                    fetch = [CommonsApp.singleton fetchWikiImage:record.title size:size];
                } else {
                    // Load the local file...
                    fetch = [record fetchThumbnail];
                }
                [fetch done:^(UIImage *image) {
                    [view setImage:image];
                }];
                [fetch fail:^(NSError *error) {
                    NSLog(@"Failed to download image: %@", [error localizedDescription]);
                    // Pop back after a second if image failed to download
                    [self performSelector:@selector(popViewControllerAnimated) withObject:nil afterDelay:1];
                }];
            }
            
        }
        
    }
    
}

- (void)viewDidUnload {
    [self setImagePreview:nil];
    [self setTitleTextField:nil];
    [self setDescriptionTextView:nil];
    [self setSelectedRecord:nil];
    [self setImageSpinner:nil];
    [self setDeleteButton:nil];
    [self setActionButton:nil];
    [self setUploadButton:nil];
    [self setTitleLabel:nil];
    [self setDescriptionLabel:nil];
    [self setLicenseLabel:nil];
    [super viewDidUnload];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    CommonsApp *app = CommonsApp.singleton;
    FileUpload *record = self.selectedRecord;
    NSLog(@"setting title: %@", self.titleTextField.text);
    record.title = self.titleTextField.text;
    [app saveData];
    [self updateUploadButton];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    CommonsApp *app = CommonsApp.singleton;
    [app saveData];
}

- (void)textViewDidChange:(UITextView *)textView
{
    self.descriptionPlaceholder.hidden = (textView.text.length > 0);

    FileUpload *record = self.selectedRecord;
    NSLog(@"setting desc: %@", self.descriptionTextView.text);
    record.desc = self.descriptionTextView.text;
    [self updateUploadButton];
}

- (IBAction)deleteButtonPushed:(id)sender {
    CommonsApp *app = CommonsApp.singleton;
    [app deleteUploadRecord:self.selectedRecord];
    self.selectedRecord = nil;
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)uploadButtonPushed:(id)sender {
    MyUploadsViewController *controller = [self.navigationController.viewControllers objectAtIndex:0];
    if ([controller respondsToSelector:@selector(uploadButtonPushed:)]) {
        [controller performSelector:@selector(uploadButtonPushed:) withObject:controller.uploadButton];
    }
    [self popViewControllerAnimated];
}

@end
