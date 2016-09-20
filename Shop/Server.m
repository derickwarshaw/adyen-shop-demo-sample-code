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

    NSLog(@"Performing request to: %@, data: \n%@", request.URL.absoluteString, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    
    NSOperationQueue *queue = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               NSLog(@"error: %@", connectionError);
                               NSLog(@"Response: %@, code: %i, data: \n%@", response, (int)[(NSHTTPURLResponse*)response statusCode], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                               
                             id json = nil;
                             if (data) {
                                 json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                             }
                               
                               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                   completion(json, connectionError);
                               });
                               
                             
                           }];
}

+ (NSMutableURLRequest *)requestPath:(NSString *)path method:(NSString *)method params:(NSDictionary *)params {

    NSString *baseUrl = @"http://madyen.mrt.io";
    //NSString *baseUrl = @"http://172.20.14.93:8080";
    //NSString *baseUrl = @"http://localhost:8080";

    NSURL *url = [NSURL URLWithString:baseUrl];
    url = [url URLByAppendingPathComponent:path];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:20.0];

    if ([method isEqualToString:@"GET"]) {

    } else if ([method isEqualToString:@"POST"]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
        [request setHTTPBody:data];
    }

    [request setHTTPMethod:method];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];

    [request setValue:@"Bearer 1811645d-87a1-4e47-833a-78a1d5f6d4" forHTTPHeaderField:@"Authorization"];

    return request;
}

@end
