//
//  DB.m
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "DB.h"
#import <PassKit/PassKit.h>

@implementation DB

+ (DB *)shared {
    static DB* instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupDefaults];
        [self setupItems];
    }
    return self;
}

- (NSString *)currencySymbol {
    if ([self.currency isEqualToString:@"EUR"]) {
        return @"€";
    } else if ([self.currency isEqualToString:@"GBP"]) {
        return @"£";
    } else {
        return @"$";
    }

}

- (void)setupDefaults {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ud stringForKey:@"endpoint"]) {
        [ud setObject:@"madyen.mrt.io" forKey:@"endpoint"];
    }
    if (![ud stringForKey:@"token"]) {
        [ud setObject:@"1811645d-87a1-4e47-833a-78a1d5f6d4" forKey:@"token"];
    }
    [ud synchronize];
}

- (void)setupItems {
    NSArray *is = @[
  @[@"Coffee",      @"Our biggest excuse why we don't do work before 9", @"1.21"],
  @[@"Cappuccino",  @"When you're bored with coffee and feeling fancy", @"2.25"],
  @[@"Humburger",   @"All you can eat sandwich. The 3-some on your plate.", @"5.25"],
  @[@"Pen",   @"Looks like a pen...", @"0.05"],
  @[@"Pen",         @"Buy one or steal one from your college", @"0.51"],
  @[@"Pencil", @"Looks like a pencil...", @"0.01"],
  @[@"Pencil",      @"That will work in space with zero gravity!", @"1.11"],
  @[@"Idea",        @"Good ideas come from everywhere, but the best ones come from developers", @"7.99"],
  @[@"Support",     @"A call from the support team", @"3.31"],
  @[@"Fix",         @"Quick fix from IS department.", @"9.99"],
  @[@"Newspaper",   @"If you feel you want to know what's going on", @"1.99"],
  @[@"Test 1.00",   @"Test product #1", @"1.00"],
  @[@"Test 2.00",   @"Test product #2", @"2.00"],
  @[@"Test 5.00",   @"Test product #3", @"5.00"],
  @[@"Test 3.00",   @"Test product #4", @"3.00"],
  @[@"Test 18.00",   @"Test product #5", @"18.00"],
  ];
    
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:is.count];
    for (NSArray *a in is) {
        SItem *item = [SItem new];
        item.title = a[0];
        item.subtitle = a[1];
        item.price = [NSDecimalNumber decimalNumberWithString:a[2]];
        [arr addObject:item];
    }
    
    self.items = arr;
    self.cartItems = [NSMutableArray array];
    
    self.currency = @"GBP";
    
}

- (void)_cartUpdated {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CartUpdated" object:nil];
}

- (BOOL)hasItemInCart:(SItem *)item {
    if ([self.cartItems containsObject:item]) {
        return YES;
    }
    return NO;
}

- (void)addItemToCart:(SItem *)item {
    [self.cartItems addObject:item];
    [self _cartUpdated];
}

- (void)deleteItemFromCart:(SItem *)item {
    [self.cartItems removeObject:item];
    [self _cartUpdated];
}

- (void)deleteCart {
    self.cartItems = [NSMutableArray array];
    [self _cartUpdated];
}

- (SItem *)itemForIndexPath:(NSIndexPath *)indexPath {
    return self.items[indexPath.row];
}

- (SItem *)cartItemForIndexPath:(NSIndexPath *)indexPath {
    return self.cartItems[indexPath.row];
}

- (NSArray *)paymentItems {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:self.cartItems.count];
    
    for (SItem *item in self.cartItems) {
        PKPaymentSummaryItem *si = [PKPaymentSummaryItem summaryItemWithLabel:item.title amount:item.price];
        [a addObject:si];
    }
    return a;
}


- (NSDecimalNumber *)totalCartAmount {
    NSDecimalNumber *num = [NSDecimalNumber zero];
    
    for (SItem *item in self.cartItems) {
        num = [num decimalNumberByAdding:item.price];
    }
    return num;
}


@end
