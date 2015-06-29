//
//  DB.h
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SItem.h"

@interface DB : NSObject

@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableArray *cartItems;
@property (nonatomic, strong) NSString *currency;

@property (nonatomic, assign) BOOL test;

+ (DB *)shared;

- (NSString *)currencySymbol;

- (BOOL)hasItemInCart:(SItem *)item;
- (void)addItemToCart:(SItem *)item;
- (void)deleteItemFromCart:(SItem *)item;
- (void)deleteCart;

- (SItem *)itemForIndexPath:(NSIndexPath *)indexPath;
- (SItem *)cartItemForIndexPath:(NSIndexPath *)indexPath;

- (NSArray *)paymentItems;
- (NSDecimalNumber *)totalCartAmount;

@end
