//
//  CartViewController.m
//  Shop
//
//  Created by Taras Kalapun on 11/10/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "CartViewController.h"
#import "DB.h"
#import "SItemCell.h"
#import "PaymentController.h"
#import "Server.h"

#define ShowAlert(title, text) [[[UIAlertView alloc] initWithTitle:title message:text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show]

#define ShowError(error) [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show]

@interface CartViewController () <PaymentControllerDelegate>
@property (nonatomic, weak) IBOutlet UIButton *payButton;
@property (nonatomic, weak) IBOutlet UISegmentedControl *deliverySegmentedControl;

// Apple pay
@property (nonatomic, strong) PaymentController *paymentController;
@property (nonatomic, assign) BOOL doDelivery;

@end

@implementation CartViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [[DB shared] addItemToCart:[DB shared].items.lastObject];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:@"CartUpdated" object:nil];
    [self update];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.payButton.hidden) {
        return;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)update {
    [self.tableView reloadData];
}

- (IBAction)pickupTypeChanged:(id)sender {
    UISegmentedControl *sc = sender;
    self.doDelivery = (sc.selectedSegmentIndex == 1);
}

#pragma mark - Payment



- (IBAction)startPayment:(id)sender {
    
    NSMutableArray *items = [NSMutableArray new];
    
    for (SItem *item in [DB shared].cartItems) {
        PKPaymentSummaryItem *si = [PKPaymentSummaryItem summaryItemWithLabel:item.title amount:item.price];
        [items addObject:si];
    }
    
    NSString *ref = [NSString stringWithFormat:@"TMRef%.0f", [NSDate timeIntervalSinceReferenceDate]];
    
    self.paymentController  = [PaymentController new];
    [self.paymentController startPaymentWithDelegate:self merchantReference:ref items:items doDelivery:self.doDelivery];
    
}

#pragma mark - PaymentControllerDelegate

- (void)paymentControllerFinishedWithResponse:(NSDictionary *)data error:(NSError *)error {
    if (error) {
        ShowError(error);
        return;
    }
    if (data) ShowAlert(@"Cool", [data description]);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [DB shared].cartItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SItemCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    SItem *item = [[DB shared] cartItemForIndexPath:indexPath];

    cell.item = item;

    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        //[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        SItem *item = [[DB shared] cartItemForIndexPath:indexPath];
        [[DB shared] deleteItemFromCart:item];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}

@end
