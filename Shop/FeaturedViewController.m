//
//  FeaturedViewController.m
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "FeaturedViewController.h"
#import "DB.h"
#import "SItemCell.h"
#import "UIBezierPath+Smoothing.h"



@interface FeaturedViewController ()

@end

@implementation FeaturedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    UITabBarController *tbc = (id)[UIApplication sharedApplication].keyWindow.rootViewController;
    tbc.selectedIndex = 1;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [DB shared].items.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    SItem *item = [[DB shared] itemForIndexPath:indexPath];
    cell.item = item;
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    
    SItem *item = [[DB shared] itemForIndexPath:indexPath];
    
    if ([[DB shared] hasItemInCart:item]) {
        return;
    }
    
    CGPoint endPoint = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height - 100);
    endPoint = [cell.contentView convertPoint:endPoint fromView:self.view];
    CGPoint centerPoint = [cell.contentView convertPoint:self.view.center fromView:self.view];
    
    CGPoint p1 = centerPoint;
    p1.y -= 100;
    
    CGPoint p2 = centerPoint;
    p2.x += 110;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:cell.imageView.center];
    //[path moveToPoint:centerPoint];
    //[path moveToPoint:endPoint];
    [path addCurveToPoint:endPoint controlPoint1:p1 controlPoint2:p2];
    
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animation];
    anim.keyPath = @"position";
    anim.path = path.CGPath;
    anim.duration = 0.5;
//    orbit.repeatCount = HUGE_VALF;
    anim.calculationMode = kCAAnimationPaced;
//    orbit.rotationMode = kCAAnimationRotateAuto;
    
    anim.timingFunctions = @[
                                 [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                 [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                                 ];
    
    [cell.imageView.layer addAnimation:anim forKey:@"move"];
    
    
    [[DB shared] addItemToCart:item];
}

@end
