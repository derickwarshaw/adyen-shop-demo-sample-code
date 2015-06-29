//
//  Server.h
//  Shop
//
//  Created by Taras Kalapun on 6/29/15.
//  Copyright © 2015 Adyen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Server : NSObject

+ (void)GET:(NSString *)path parameters:(NSDictionary *)params
 completion:(void (^)(id JSON, NSError *error))completion;

+ (void)POST:(NSString *)path parameters:(NSDictionary *)params
  completion:(void (^)(id JSON, NSError *error))completion;

// this one is here for performing some custom requests
+ (void)performRequest:(NSURLRequest *)request
            completion:(void (^)(id JSON, NSError *error))completion;

@end
