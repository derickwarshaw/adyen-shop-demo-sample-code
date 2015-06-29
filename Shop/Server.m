//
//  Server.m
//  Shop
//
//  Created by Taras Kalapun on 6/29/15.
//  Copyright © 2015 Adyen. All rights reserved.
//

#import "Server.h"

@implementation Server

+ (void)GET:(NSString *)path parameters:(NSDictionary *)params completion:(void (^)(id, NSError *))completion {
    NSURLRequest *request = [self requestPath:path method:@"GET" params:params];
    [self performRequest:request completion:completion];
}

+ (void)POST:(NSString *)path parameters:(NSDictionary *)params completion:(void (^)(id, NSError *))completion {
    NSURLRequest *request = [self requestPath:path method:@"POST" params:params];
    [self performRequest:request completion:completion];
}

+ (void)performRequest:(NSURLRequest *)request completion:(void (^)(id, NSError *))completion {
    
    NSOperationQueue *queue = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               id json = nil;
                               if (data) {
                                   json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                               }
                               completion(json, connectionError);
                           }];
    
}


+ (NSMutableURLRequest *)requestPath:(NSString *)path method:(NSString *)method params:(NSDictionary *)params {
    
    //    NSString *baseUrl = @"http://madyen.mrt.io/payments";
    NSString *baseUrl = @"http://localhost:8080";
    
    NSURL *url = [NSURL URLWithString:baseUrl];
    url = [url URLByAppendingPathComponent:path];
    
    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:url
                            cachePolicy:NSURLRequestReloadIgnoringCacheData
                        timeoutInterval:10.0];
    
    
    if ([method isEqualToString:@"GET"]) {
        
    } else if ([method isEqualToString:@"POST"]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
        [request setHTTPBody:data];
    }
    
    [request setHTTPMethod:method];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    
    return request;
}

@end
