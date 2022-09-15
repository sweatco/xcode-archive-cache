//
//  ViewController.m
//  SiblingProjects
//
//  Created by Ilya Dyakonov on 14.09.2022.
//

#import "ViewController.h"
#import "StaticLibrary.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.label.text = [[StaticLibrary new] something];
}


@end
