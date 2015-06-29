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

@interface PaymentController ()<PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) NSString *merchantName;
@property (nonatomic, strong) NSString *merchantReference;
@property (nonatomic, strong) NSArray *paymentItems;
@end

@implementation PaymentController

- (instancetype)init
{
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
    request.supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex];
    request.merchantCapabilities = PKMerchantCapability3DS;
    
    request.merchantIdentifier = @"merchant.com.adyen";
    request.countryCode = @"GB";
    request.currencyCode = @"GBP"; //[DB shared].currency;
    
    PKShippingMethod *shippingMethod = nil;
    if (doDelivery) {
        request.requiredShippingAddressFields = PKAddressFieldAll;
    }
    
    NSArray *summaryItems = [self summaryItemsForShippingMethod:nil];
    
    request.paymentSummaryItems = summaryItems;
    
    
    if ([self.totalAmount doubleValue] <= 0) {
        NSError *error = [self errorWithCode:PaymentControllerErrorAmountTooLow description:@"Total must be greater than zero" error:nil];
        [self.delegate paymentControllerFinishedWithError:error];
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
    
    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex]]) {
        NSError *error = [self errorWithCode:PaymentControllerErrorCantMakePayments description:@"Payments not possible with selected networks" error:nil];
        [self.delegate paymentControllerFinishedWithError:error];
        return NO;
    }
    return YES;
}

- (void)presentPaymentViewController {
    
    PKPaymentAuthorizationViewController *vc = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:self.paymentRequest];
    
    if (!vc) {
        NSError *error = [self errorWithCode:PaymentControllerErrorCantMakePayments description:@"Cannot start payments" error:nil];
        [self.delegate paymentControllerFinishedWithError:error];
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
    
    if ([DB shared].test) {
        NSString *testToken = [self.class testTokenGBPForAmount:amount];
        if (testToken) d[@"paymentData"] = testToken;
    }
    
    PKPaymentRequest *request = self.paymentRequest;
    
    d[@"currencyCode"] = request.currencyCode;
    d[@"countryCode"]  = request.countryCode;
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
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
    if (!payment.token.paymentData) {
        NSError *error = [self errorWithCode:PaymentControllerErrorNoPaymentToken description:@"No payment token" error:nil];
        [self.delegate paymentControllerFinishedWithError:error];
        completion(PKPaymentAuthorizationStatusFailure);
        return;
    }
    
    NSDictionary *paymentDict = [self combinedDictionaryForPayment:payment];
    
    NSLog(@"Payment dict: %@", paymentDict);
    
    [Server POST:@"/pay" parameters:paymentDict completion:^(id JSON, NSError *connectionError) {
        if (connectionError || !JSON) {
            NSError *error = [self errorWithCode:PaymentControllerErrorServerError description:@"Connection error" error:connectionError];
            [self.delegate paymentControllerFinishedWithError:error];
            completion(PKPaymentAuthorizationStatusFailure);
            return;
        }
        completion(PKPaymentAuthorizationStatusSuccess);
        [self.delegate paymentControllerFinishedWithError:nil];
    }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingAddress:(ABRecordRef)address
                                completion:(void (^)(PKPaymentAuthorizationStatus status, NSArray *shippingMethods, NSArray *summaryItems))completion {
    
    ADYABRecord *record = [ADYABRecord recordFromABRecord:address];
    [Server POST:@"/shipping" parameters:record.toDictionary completion:^(id JSON, NSError *connectionError) {
        if (connectionError) {
            NSError *error = [self errorWithCode:PaymentControllerErrorServerError description:@"Connection error" error:connectionError];
            completion(PKPaymentAuthorizationStatusFailure, nil, nil);
            [self.delegate paymentControllerFinishedWithError:error];
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


- (NSArray *)summaryItemsForItems:(NSArray *)items shippingMethod:(PKShippingMethod *)shippingMethod withTotalLabel:(NSString *)totalLabel
{
    
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
    NSArray *summaryItems =  [self summaryItemsForItems:self.paymentItems
                                             shippingMethod:shippingMethod
                                             withTotalLabel:self.merchantName];
    
    self.totalAmount = [(PKPaymentSummaryItem *)summaryItems.lastObject amount];
    
    return summaryItems;
}

+ (NSString *)testTokenGBPForAmount:(NSDecimalNumber *)amount {
    if (amount.intValue == 1) {
        return @"eyJ2ZXJzaW9uIjoiQWR5ZW5fVGVzdCIsInNpZ25hdHVyZSI6IlptRnJaU0J6YVdkdVlYUjFjbVU9IiwiaGVhZGVyIjp7ImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRW14Q2hDcGpLemY5YVh6MjZXVDZaVE4yekUzaUdYUWpjWlJZWUFkUUlURFgyUmtBTmJ0N2s5cmFoRjFoempqbWVWVHhjZ0NvZkg4MXprMkdOVFozZHRnPT0iLCJwdWJsaWNLZXlIYXNoIjoiT3JXZ2pSR2txRVdqZGtSZFVyWGZpTEdEMGhlL3pwRXU1MTJGSldyR1lGbz0iLCJ0cmFuc2FjdGlvbklkIjoiMTIzNDU2Nzg5MEFCQ0RFRiJ9LCJkYXRhIjoiMWRYRTEza3Z6VFZQNm5XRU44RDJwaHJQbGZRY0dyOFczeWoyU0hZWWovUHljSFdUam5wVjd6L0VyNzhicmltQWliVDFmbjN5Qjd5QjIwSUdJWEdMaENFWXpMcTUwM0lEeStvYlZaWmtEdEp6VTBBaTBiWmtSRTV1eTdqT2xzL21KbHlPL0xPeDZLRVMyd2o1cjcxR1RURWp2dUFMZmoxNjVDUUF0djdlRUE3M3FaeUdmQzVCRHBOSGl2amQySVJyOEE0ZGNEYk50TlcvRVVZVGtEN3VRbUNXUnJvUEV0Y0VSeW9md1daL1A0Ti9ISXN5Q2FMSDczOUVSU29ydFRZeDdqOE1vUEhkTVpHS0MzaDNjc0p4dkxoN2tGcjc3VkZLWVRlMWVpbURmeStmc1BMVzZaS296eXNOR0JtaE83bmdtWFBPY3lBZjNNd2c2V2JrNDJNSm9pOGJDenl3c2piVWhFcGROZ1ptbkNONTdVMXBiSG9MUCtoYlFUSUtiVGJmZlhkWlZ6SjZFa3Q0TERDempCUkY3eWwvaTFsQlVjYXVIMTBzb1NNQlZlK2wxRjAzVGNkNzhzSlc1TDd1djloNGVPenR6bXZibGszZHg0d21wOTJlQ2NjWFhjVSs5T1l2ZHZ5NG4rTGh4N3hhayt1bDhMK20ifQ==";
    }
    
    if (amount.intValue == 2) {
        return @"eyJ2ZXJzaW9uIjoiQWR5ZW5fVGVzdCIsInNpZ25hdHVyZSI6IlptRnJaU0J6YVdkdVlYUjFjbVU9IiwiaGVhZGVyIjp7ImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRUZXWHF6TWxKRW5rRStFdi92eXNtQ0lJYklMNU5DendQUnk5V2JINjNGcWg1eXBoUjJBWTUxL1E2NTJENjlyNk95Y3B2Rmo5QmNvakpBZEtmVXlzT3RnPT0iLCJwdWJsaWNLZXlIYXNoIjoiT3JXZ2pSR2txRVdqZGtSZFVyWGZpTEdEMGhlL3pwRXU1MTJGSldyR1lGbz0iLCJ0cmFuc2FjdGlvbklkIjoiMTIzNDU2Nzg5MEFCQ0RFRiJ9LCJkYXRhIjoiUmdXaE5SelpxUUZXV0Jhd2ZDek8yZkxxUWpManhuZjUrVHkwUUtoeFc0L2lkaUZGaVB3VFBzbUtaUHh6eXJBU0J2LzJKUk9odG9TZmMwSWtJb1Z4ZHI4dUFqSGZsaWdyZGVHc2cycGFXS0dKS2kzT1dqeXNmeWI3NTlTaWVQWWRROEFtM2ZPY2cwS2dWWENmamRaRERyTk5jSzhmb01NMHBVRTRPV3dxSUd3bFV5UWNqMXIvczhpM2ViNXNic2JNeEE1OTBGSWFzc0p5MDZFN0RBWjdOdkphYThYZjhXV1pTOVBnREp3TXQ0aFlIcmZWVFpDNEtOaG95OTQwcFlaNkFBSzluRjNEMHBsVmszOGdMUGFoa0VqZmJPSmU3SEt3eGdtbmxaUzV1YVA2VFJrNHo1d0pDdU9jY1BPWGord283UXR6OXdHd0cwMzg1dGtndFlTRlExU2VZQlRHK2dRQk5PRzdMSnZPR0tBSzEranZpbzE4VDZNTjA0KzBjUjJvNkdLREphRnpQOWVQOUFybU9jdkR4Vml2QU1iQUV2dGZGdHdPYVE4NnltTHV0UDQrMzJ2NHV5MmZpUDE3SmQ3UlJDUmFhSGx1NkZCck5uaHRVbDBlQytWWEFDRURHTWp6Q1hMUkJQVEJTOHlPa0R5WTB0RFMifQ";
    }
    
    if (amount.intValue == 3) {
        return @"eyJ2ZXJzaW9uIjoiQWR5ZW5fVGVzdCIsInNpZ25hdHVyZSI6IlptRnJaU0J6YVdkdVlYUjFjbVU9IiwiaGVhZGVyIjp7ImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRUlpMlFhUVE0QnVsc2pueStvRys4SFFzZUxRa2g0NndSTTNMaVdPT01XamJ6NWt1Z3ovcEppcWR1Tk1IZysvK1BQQ1VYUmUzT2NOcTNyMC9xQlhEL2pnPT0iLCJwdWJsaWNLZXlIYXNoIjoiT3JXZ2pSR2txRVdqZGtSZFVyWGZpTEdEMGhlL3pwRXU1MTJGSldyR1lGbz0iLCJ0cmFuc2FjdGlvbklkIjoiMTIzNDU2Nzg5MEFCQ0RFRiJ9LCJkYXRhIjoiNTlSeDlOMUZGZkxOdXhzV1haVUJNQktBeGgxSGFzQmNYRnlCeGNMeVo0dEhVcnNWaFIrSGJERndBWnBNS0pXcHBLYmI1LzZPdnJncUJWUUk3T21ETk4yYUNTelJlZENlVHg3QzJROXNxcm5xVHdhcE9jQVpma2ZMUGFNWno3YVhzeHFCN0MxZ2dvZ3kyR21uY0p4c0VzYkVVSkxtOTlzYk1jZ3VPdnhDZmozb1JLdFZGMlJNNENtZG1sb0d1S2g2bnJCRCtXQUJaVmFvYUE0cFNrT1lQOFFHYnBtemo5MGoyVk16aXBSWkQ4Q0pxN2t1Y0E2eWNORlpUNU9rUk1HK0JJeHFuSSs1SStXTStXbXpYa2tVVUlyakRkOUxscjl2bUxXT3Zuekt6U1BSOTlWYWdpQUZ4R0FjT25GUS9jNmozN2ZWMnp5MEJ4SkxpWVZ1MGl4cVI1WGh1UUFRcUY5M1N4eHh0K25JclRERlBNUlhoZVBFNGRjbjNLdUhaSWpCUHFES1ZkOUloQVR1ejBQUTBCS04wdWdnSmFUb1ZsZXJNVkkrcnZJRkIyb2dISGdxaWdVc202a2hqMXd3bTlabHBHZkdyMjNHaGlMWEtya3p6TkFpREZKVEU1MzRpTFRUa3RGUW5vL21jZ3h6R2cyVzh5NHoifQ==";
    }
    
    if (amount.intValue == 5) {
        return @"eyJ2ZXJzaW9uIjoiQWR5ZW5fVGVzdCIsInNpZ25hdHVyZSI6IlptRnJaU0J6YVdkdVlYUjFjbVU9IiwiaGVhZGVyIjp7ImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRTU1aVBwcHBPaGlDaDZteklUQTdOUmVZZ1NGRk0zWWx5cURqUGtGNzdYRXRUR2tSTnVMMUJvVFlJNWxWVVkwSW45R3ZIZ2FlMkJialY1SC9WMmhGK093PT0iLCJwdWJsaWNLZXlIYXNoIjoiT3JXZ2pSR2txRVdqZGtSZFVyWGZpTEdEMGhlL3pwRXU1MTJGSldyR1lGbz0iLCJ0cmFuc2FjdGlvbklkIjoiMTIzNDU2Nzg5MEFCQ0RFRiJ9LCJkYXRhIjoiaklNVmo0THFJUGZQOXZrSm9rSlVlV0toVE95b3VUa0ZlTHlzaXVsWW4rZGhsaXZHV0lZWGV6Z0M5eVAwK25DM2o0TGpmY24vKy9mWTFuTGY1WlRlT2pvVDVqUHVjNkhaNjA3VUU4SzVGSWc4ZVRVbG9ZMXF1bnBIWjBWbHRIZldLamdIc0pSOHNjNmhPWUFibmtMZmRXc3F2Nm5BbXZETmJJc0xpTkVMaXBjR3RQQ0Zxb0ZIUjlhVFBacjVlMzhCOTdKY1NBTUFuRTA5cnJxMU1ER091eXRsM2tBY3JsOU1HRkRvT3NHeWt4WnBXZjloMUk5Q1NHWXFLYmJJME4zSmlXaGN1VHVJOG1VckpLNlJUNi80ZENySW9HSkxiREo5NXdWZXVCcXRoVU5VN0I0djVHRnlRRGZJQ2lRU1dxOGdkNDdDd21Qb2V3Rm40ZUd1WlVRMzcvb0R4TURid1NzRFVsQzE1YXJFTmhaYWRaRVVQcCtHdWs4RGlpRU9WSDZHbjFvcGtPbEx5Y3U0MVRPYlkwWjBUR2h4ajlCYVR0NjVRcmI4UC9iaWNHZ01VVjBDdGNCYmdkbnpXTTBhNlJHeExnWS9WWjhUdXZ3SFBza1M2VjloU2xDUUt0dCtjbnZuaWt2K05scGRkaHB3ZmNqTHdSckUifQ0K";
    }
    
    if (amount.intValue == 18) {
        return @"eyJ2ZXJzaW9uIjoiQWR5ZW5fVGVzdCIsInNpZ25hdHVyZSI6IlptRnJaU0J6YVdkdVlYUjFjbVU9IiwiaGVhZGVyIjp7ImVwaGVtZXJhbFB1YmxpY0tleSI6Ik1Ga3dFd1lIS29aSXpqMENBUVlJS29aSXpqMERBUWNEUWdBRVB6Q29UaXUzYi8zM1lyT3JBMCtXdWFFcDFyQjNoMFh0SENUNVhXTVhoM0F0cmhxeFBZb29yMU5NSWdvUmovK2ZpS3U0aHBQZUFmWEVoUVBhZEJjQVJBPT0iLCJwdWJsaWNLZXlIYXNoIjoiT3JXZ2pSR2txRVdqZGtSZFVyWGZpTEdEMGhlL3pwRXU1MTJGSldyR1lGbz0iLCJ0cmFuc2FjdGlvbklkIjoiMTIzNDU2Nzg5MEFCQ0RFRiJ9LCJkYXRhIjoiOUlmU0ZNTDFVN09nbC9Wb0NCM01ONzE1eTFjTG13dEpFelNsVDd1MS8yNWRSTkhRcGlsNmExZDRwQ2l6RFFPbHpZcWloYmI5TThHc0RhckN6dW9zTE9zcnFOb3VKYnBUdmNDK2V5a0ljWTBlK1ZreStyY1Z3V0FjWFRrelFxWHlPY1hqdEZjdTduSDR5NnBvNU5oaXpRSHNHK3BLZGRLNGNFMUNiWEtCM28rcHVpMmdVblpZWlo5dXdVNjhZck1iODRjQUJ6TXVtQWE4Zkd5aUU5YzVWNEFBa211dURkWVU2bDU0SlRKSkN0a1JxR2tVTlF5WE9EYy9XeWNva25pRDNlMktwYjBtSHpRbU51WVg3VVUxOWg5cTRHQVo2V0lKbWRoUzJYODhHRDVZc1JLNy8vYXJRbkxXZk5FOU5BL1N1MlNVNnU2a3ljdmNqTlRQNjF6NStVSnJmOWNIT1NZWFgvQmttT0NsWlUycU1oQkwzV3J5QVQ1eUtVUG0rTzNmSHVhZzRDekF1bUVoMTUydW1QMlI0NXRDTzVySFNRWFNpaytYMEhXTkdRdTVoa0pNNlgwbUpRa1FqMDdpbC9XWmUwV0syMlZHT0hUVUtiVzZhTzkwWWVjNjIwZ2pLMkVXUmJXSGtoVlNpOGZYVWtaTkJNT2RYZz09In0=";
    }
    
    return nil;
}

@end
