//
//  PaymentController.h
//  Shop
//
//  Created by Taras Kalapun on 3/12/15.
//  Copyright (c) 2015 Adyen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

typedef enum : NSUInteger {
    PaymentControllerErrorCantMakePayments,
    PaymentControllerErrorAmountTooLow,
    PaymentControllerErrorNoPaymentToken,
    PaymentControllerErrorServerError,
} PaymentControllerError;

@protocol PaymentControllerDelegate <NSObject>

- (void)paymentControllerFinishedWithError:(NSError *)error;

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:(void (^ __nullable)(void))completion;
- (void)dismissViewControllerAnimated: (BOOL)flag completion: (void (^ __nullable)(void))completion;

@end

@interface PaymentController : NSObject

@property (nonatomic, assign) id<PaymentControllerDelegate> delegate;

@property (nonatomic, strong) NSDecimalNumber *totalAmount;

@property (nonatomic, strong) PKPaymentRequest *paymentRequest;

- (void)startPaymentWithDelegate:(id<PaymentControllerDelegate>)delegate merchantReference:(NSString *)reference items:(NSArray *)items doDelivery:(BOOL)doDelivery;
+ (BOOL)canMakePayments;

@end
