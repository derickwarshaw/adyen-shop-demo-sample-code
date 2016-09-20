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
    
    [super awakeFromNib];
    
    CGRect frame = CGRectMake(0, 0, 60, 28);
    
    self.priceLabel = [[UILabel alloc] initWithFrame:frame];
    self.priceLabel.font = [UIFont systemFontOfSize:18.f weight:UIFontWeightMedium];
    self.priceLabel.textColor = [UIColor darkTextColor];
    self.priceLabel.textAlignment = NSTextAlignmentRight;
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
    
    NSString *sp = [NSString stringWithFormat:@"%@%@",
                    DB.shared.currencySymbol, self.price.stringValue];
    self.priceLabel.text = sp;
    //[self.priceButton setTitle:sp forState:UIControlStateNormal];
}

@end
