//
//  PaymentController.m
//  Shop
//
//  Created by Taras Kalapun on 3/12/15.
//  Copyright (c) 2015 Adyen. All rights reserved.
//

#import "PaymentController.h"

#import "ADYABRecord.h"
#import "Server.h"
#import "DB.h"

@interface PaymentController () <PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) NSString *merchantName;
@property (nonatomic, strong) NSString *merchantReference;
@property (nonatomic, strong) NSArray *paymentItems;
@end

@implementation PaymentController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.merchantName = @"Adyen";
    }
    return self;
}

- (NSError *)errorWithCode:(PaymentControllerError)code description:(NSString *)description error:(NSError *)underlyingError {

    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:1];

    if (description) {
        d[NSLocalizedDescriptionKey] = description;
    }

    if (underlyingError) {
        d[NSUnderlyingErrorKey] = underlyingError;
    }

    NSError *error = [[NSError alloc] initWithDomain:@"com.adyen.ApplePay" code:code userInfo:d];
    return error;
}

- (void)startPaymentWithDelegate:(id<PaymentControllerDelegate>)delegate merchantReference:(NSString *)reference items:(NSArray *)items doDelivery:(BOOL)doDelivery {

    self.delegate = delegate;

    if (![self canMakePayments]) return;

    self.merchantReference = reference;
    self.paymentItems = items;

    PKPaymentRequest *request = [PKPaymentRequest new];
    request.supportedNetworks = @[ PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex ];
    request.merchantCapabilities = PKMerchantCapability3DS;

    request.merchantIdentifier = @"merchant.com.adyen.test";
    request.countryCode = @"GB";
    request.currencyCode = [DB shared].currency;

    if (doDelivery) {
        request.requiredShippingAddressFields = PKAddressFieldAll;
    }

    NSArray *summaryItems = [self summaryItemsForShippingMethod:nil];

    request.paymentSummaryItems = summaryItems;

    if ([self.totalAmount doubleValue] <= 0) {
        NSError *error = [self errorWithCode:PaymentControllerErrorAmountTooLow description:@"Total must be greater than zero" error:nil];
        [self.delegate paymentControllerFinishedWithResponse:nil error:error];
        return;
    }

    self.paymentRequest = request;
    [self presentPaymentViewController];
}

- (BOOL)canMakePayments {
    //    if ([PKPaymentAuthorizationViewController canMakePayments]) {
    //        ShowAlert(@"Payments not possible", nil);
    //        return NO;
    //    }

    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[ PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex ]]) {
        NSError *error = [self errorWithCode:PaymentControllerErrorCantMakePayments description:@"Payments not possible with selected networks" error:nil];
        [self.delegate paymentControllerFinishedWithResponse:nil error:error];
        return NO;
    }
    return YES;
}

- (void)presentPaymentViewController {

    PKPaymentAuthorizationViewController *vc = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:self.paymentRequest];

    if (!vc) {
        NSError *error = [self errorWithCode:PaymentControllerErrorCantMakePayments description:@"Cannot start payments" error:nil];
        [self.delegate paymentControllerFinishedWithResponse:nil error:error];
        return;
    }
    vc.delegate = self;
    [self.delegate presentViewController:vc animated:YES completion:nil];
}

- (NSDictionary *)combinedDictionaryForPayment:(PKPayment *)payment {
    NSMutableDictionary *d = [NSMutableDictionary new];

    if (payment.billingAddress) {
        d[@"billingAddress"] = [ADYABRecord recordFromABRecord:payment.billingAddress].toDictionary;
    }

    if (payment.shippingAddress) {
        d[@"shippingAddress"] = [ADYABRecord recordFromABRecord:payment.shippingAddress].toDictionary;
    }

    if (payment.shippingMethod) {
        d[@"shippingMethod"] = payment.shippingMethod.identifier;
    }

    if (payment.token) {
        d[@"transactionIdentifier"] = payment.token.transactionIdentifier;
        d[@"paymentInstrumentName"] = payment.token.paymentInstrumentName;
        d[@"paymentNetwork"] = payment.token.paymentNetwork;
        d[@"paymentData"] = [payment.token.paymentData base64EncodedStringWithOptions:0];
    }

    NSDecimalNumber *amount = self.totalAmount;
    if (amount) d[@"amount"] = amount.stringValue;

    PKPaymentRequest *request = self.paymentRequest;

    d[@"currencyCode"] = request.currencyCode;
    d[@"countryCode"] = request.countryCode;
    d[@"merchantIdentifier"] = request.merchantIdentifier;

    d[@"merchantReference"] = self.merchantReference;

    if (request.applicationData) d[@"applicationData"] = [request.applicationData base64EncodedStringWithOptions:0];

    return d;
}

- (NSArray *)shippingMethodsFromJson:(NSArray *)json {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:json.count];
    for (NSDictionary *d in json) {
        PKShippingMethod *item = [PKShippingMethod summaryItemWithLabel:d[@"label"] amount:[NSDecimalNumber decimalNumberWithString:d[@"amount"]]];
        item.detail = d[@"detail"];
        item.identifier = d[@"identifier"];
        [a addObject:item];
    }
    return a;
}

#pragma mark - PKPaymentAuthorizationViewControllerDelegate

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion {
    if (!payment.token.paymentData) {
        NSError *error = [self errorWithCode:PaymentControllerErrorNoPaymentToken description:@"No payment token" error:nil];
        [self.delegate paymentControllerFinishedWithResponse:nil error:error];
        completion(PKPaymentAuthorizationStatusFailure);
        return;
    }

    NSDictionary *paymentDict = [self combinedDictionaryForPayment:payment];

    NSLog(@"Payment dict: %@", paymentDict);

    [Server POST:@"/api/payment"
        parameters:paymentDict
        completion:^(id JSON, NSError *connectionError) {
          if (connectionError || !JSON) {
              NSError *error = [self errorWithCode:PaymentControllerErrorServerError description:@"Connection error" error:connectionError];
              [self.delegate paymentControllerFinishedWithResponse:nil error:error];
              completion(PKPaymentAuthorizationStatusFailure);
              return;
          }
            NSLog(@"Completed with response: %@", JSON);
          completion(PKPaymentAuthorizationStatusSuccess);
          [self.delegate paymentControllerFinishedWithResponse:JSON error:nil];
        }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingAddress:(ABRecordRef)address
                                completion:(void (^)(PKPaymentAuthorizationStatus status, NSArray *shippingMethods, NSArray *summaryItems))completion {

    ADYABRecord *record = [ADYABRecord recordFromABRecord:address];
    [Server POST:@"/api/shipping"
        parameters:record.toDictionary
        completion:^(id JSON, NSError *connectionError) {
          if (connectionError) {
              NSError *error = [self errorWithCode:PaymentControllerErrorServerError description:@"Connection error" error:connectionError];
              completion(PKPaymentAuthorizationStatusFailure, nil, nil);
              [self.delegate paymentControllerFinishedWithResponse:nil error:error];
              return;
          }
          if (!JSON) {
              NSArray *summaryItems = [self summaryItemsForShippingMethod:nil];
              completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress, nil, summaryItems);
              return;
          }
          NSArray *shippingMethods = [self shippingMethodsFromJson:JSON];
          NSArray *summaryItems = [self summaryItemsForShippingMethod:shippingMethods.firstObject];
          completion(PKPaymentAuthorizationStatusSuccess, shippingMethods, summaryItems);
        }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray *summaryItems))completion {
    NSArray *summaryItems = [self summaryItemsForShippingMethod:shippingMethod];
    completion(PKPaymentAuthorizationStatusSuccess, summaryItems);
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    [self.delegate dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (NSArray *)summaryItemsForItems:(NSArray *)items shippingMethod:(PKShippingMethod *)shippingMethod withTotalLabel:(NSString *)totalLabel {

    NSDecimalNumber *total = [NSDecimalNumber zero];
    for (PKPaymentSummaryItem *item in items) {
        total = [total decimalNumberByAdding:item.amount];
    }

    if (shippingMethod) {
        total = [total decimalNumberByAdding:shippingMethod.amount];
    }

    PKPaymentSummaryItem *totalItem = [PKPaymentSummaryItem summaryItemWithLabel:totalLabel amount:total];
    NSMutableArray *allItems = [NSMutableArray new];
    [allItems addObjectsFromArray:items];

    if (shippingMethod) [allItems addObject:shippingMethod];
    [allItems addObject:totalItem];

    return allItems;
}

- (NSArray *)summaryItemsForShippingMethod:(PKShippingMethod *)shippingMethod {
    NSArray *summaryItems = [self summaryItemsForItems:self.paymentItems
                                        shippingMethod:shippingMethod
                                        withTotalLabel:self.merchantName];

    self.totalAmount = [(PKPaymentSummaryItem *)summaryItems.lastObject amount];

    return summaryItems;
}


@end
