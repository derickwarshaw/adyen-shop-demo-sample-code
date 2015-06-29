//
//  ADYABHelper.h
//  Wallet
//
//  Created by Taras Kalapun on 9/23/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface ADYABRecord : NSObject


@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *phone;


@property (nonatomic, strong) NSString *street;
@property (nonatomic, strong) NSString *city;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, strong) NSString *zip;
@property (nonatomic, strong) NSString *countryCode;


- (ABRecordRef)abRecord;
+ (instancetype)recordFromABRecord:(ABRecordRef)abRecord;
+ (instancetype)recordFromDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)toDictionary;

@end
