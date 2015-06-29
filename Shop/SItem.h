//
//  SItem.h
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SItem : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSString *priceString;
@property (nonatomic, strong) UIImage *image;

@end
