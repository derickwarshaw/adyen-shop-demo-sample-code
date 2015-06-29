//
//  UIBezierPath+Smoothing.h
//  Shop
//
//  Created by Taras Kalapun on 11/11/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIBezierPath (Smoothing)

- (UIBezierPath*)smoothedPathWithGranularity:(NSInteger)granularity;

@end
