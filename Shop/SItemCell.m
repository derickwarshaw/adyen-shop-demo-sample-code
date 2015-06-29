//
//  SItemCell.m
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "SItemCell.h"
#import "DB.h"

@implementation SItemCell

- (void)awakeFromNib {
    // Initialization code
    
    CGRect frame = CGRectMake(0, 0, 60, 28);
    
//    self.priceButton = [[UIButton alloc] initWithFrame:frame];
//    self.priceButton.backgroundColor = [UIColor colorWithRed:0.71 green:0.78 blue:0.5 alpha:1];
//    [self.priceButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
//    self.priceButton.layer.cornerRadius = 5.0;
//    self.accessoryView = self.priceButton;
    
    self.priceLabel = [[UILabel alloc] initWithFrame:frame];
//    self.priceLabel.backgroundColor = [UIColor clearColor];
    self.priceLabel.font = [UIFont fontWithName:@"Avenir" size:15.0];
    self.priceLabel.textColor = [UIColor darkTextColor];
    self.accessoryView = self.priceLabel;
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setItem:(SItem *)item {
//    if (_item == item) {
//        return;
//    }
//    _item = item;
    
    self.textLabel.text = item.title;
    self.detailTextLabel.text = item.subtitle;
    self.imageView.image = item.image;
    self.price = item.price;
    
    NSString *sp = [NSString stringWithFormat:@" %@ %@",
                    DB.shared.currencySymbol, self.price.stringValue];
    self.priceLabel.text = sp;
    //[self.priceButton setTitle:sp forState:UIControlStateNormal];
}

@end
