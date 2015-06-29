//
//  SItem.m
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "SItem.h"

@implementation SItem

- (UIImage *)image {
    return [UIImage imageNamed:self.title];
}

- (NSString *)priceString {
    return self.price.stringValue;
}


@end
