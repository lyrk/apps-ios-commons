//
//  RegistrationWebViewController.h
//  Commons
//
//  Created by Constantin Müller on 07.07.15.
//  Copyright (c) 2015 Lyrk. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface RegistrationWebViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIWebView *webview;


@property (weak, nonatomic) IBOutlet UIBarButtonItem *DoneButton;

- (IBAction)DoneButtonPress:(id)sender;

@end