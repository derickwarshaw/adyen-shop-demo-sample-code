//
//  SItemCell.h
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SItem.h"

@interface SItemCell : UITableViewCell

@property (nonatomic, strong) UIButton *priceButton;
@property (nonatomic, strong) UILabel *priceLabel;

@property (nonatomic, strong) NSDecimalNumber *price;


@property (nonatomic, assign) SItem *item;

@end
