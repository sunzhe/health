//
//  DCStepViewController.m
//  Fit
//
//  Created by aaron on 16/4/30.
//  Copyright © 2016年 Apple. All rights reserved.
//

#import "DCStepViewController.h"

@interface DCStepViewController ()<UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *readStepLabel;
@property (weak, nonatomic) IBOutlet UITextField *writeStepTextField;

@end

@implementation DCStepViewController

#pragma mark - life cycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _writeStepTextField.delegate = self;
    
    HKQuantityType *stepType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    [self fetchSumOfSamplesTodayForType:stepType unit:[HKUnit countUnit] completion:^(double stepCount, NSError *error) {
        NSLog(@"%f",stepCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            _readStepLabel.text = [NSString stringWithFormat:@"%.f",stepCount];
        });
    }];
}

#pragma mark - #pragma mark - Reading HealthKit Data

- (void)fetchSumOfSamplesTodayForType:(HKQuantityType *)quantityType unit:(HKUnit *)unit completion:(void (^)(double, NSError *))completionHandler {
    NSPredicate *predicate = [self predicateForSamplesToday];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum|HKStatisticsOptionSeparateBySource completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        HKQuantity *sum = [result sumQuantity];
        //sum = [result sumQuantityForSource:[HKSource defaultSource]];
        for (HKSource *source in result.sources) {
            if ([source.name isEqualToString:[UIDevice currentDevice].name]) {
                NSLog(@"%@ -- %f",source, [[result sumQuantityForSource:source] doubleValueForUnit:[HKUnit countUnit]]);
            }
        }
        
        if (completionHandler) {
            double value = [sum doubleValueForUnit:unit];
            
            completionHandler(value, error);
        }
    }];
    
    [self.healthStore executeQuery:query];
    return;
    HKSampleType *type = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    
    HKSampleQuery *squery = [[HKSampleQuery alloc] initWithSampleType:type predicate:predicate limit:HKObjectQueryNoLimit sortDescriptors:@[timeSortDescriptor] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        HKQuantity *lastQuantiy = nil;
        for (HKQuantitySample *sample in results) {
            HKQuantity *quantity = sample.quantity;
            //NSLog(@"name = %@", quantity.sour);
            lastQuantiy = quantity;
        }
        
    }];
    [self.healthStore executeQuery:squery];
}

#pragma mark - Convenience

- (NSPredicate *)predicateForSamplesToday {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *now = [NSDate date];
    
    NSDate *startDate = [calendar startOfDayForDate:now];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    return [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
}


#pragma mark - #pragma mark - writing HealthKit Data

- (IBAction)doneDidiClick:(UIButton *)sender {
    
    [self addstepWithStepNum:_writeStepTextField.text.doubleValue];
}

- (void)addstepWithStepNum:(double)stepNum {
    // Create a new food correlation for the given food item.
    NSArray *samples = [self stepCorrelationWithStepNum:stepNum];
    [self.healthStore saveObjects:samples withCompletion:^(BOOL success, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_writeStepTextField resignFirstResponder];
            if (success) {
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
            }else {
                NSLog(@"The error was: %@.", error);
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
                return ;
            }
        });
    }];
    return;
    HKQuantitySample *stepCorrelationItem = samples.firstObject;
    [self.healthStore saveObject:stepCorrelationItem withCompletion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.view endEditing:YES];
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
            }
            else {
                NSLog(@"The error was: %@.", error);
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
                return ;
            }
        });
    }];
    
}

- (NSArray *)stepCorrelationWithStepNum:(double)stepNum {
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:-38];
    NSDate *startDate = [NSDate dateWithTimeInterval:-59 sinceDate:endDate];
    
    HKQuantity *stepQuantityConsumed = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:stepNum];
    
    HKQuantityType *stepConsumedType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    UIDevice *cdevice = [UIDevice currentDevice];
    HKDevice *device = [[HKDevice alloc] initWithName:cdevice.model manufacturer:@"Apple" model:cdevice.model hardwareVersion:@"iPhone8,1" firmwareVersion:nil softwareVersion:cdevice.systemVersion localIdentifier:nil UDIDeviceIdentifier:nil];
//    NSDictionary *stepCorrelationMetadata = @{HKMetadataKeyUDIDeviceIdentifier: @"aaron's test equipment",
//                                                  HKMetadataKeyDeviceName:@"iPhone",
//                                                  HKMetadataKeyWorkoutBrandName:@"Apple",
//                                                  HKMetadataKeyDeviceManufacturerName:@"Apple"};
    HKQuantitySample *stepConsumedSample = [HKQuantitySample quantitySampleWithType:stepConsumedType quantity:stepQuantityConsumed startDate:startDate endDate:endDate device:device metadata:nil];
    
    HKQuantityType *distanceType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    
    HKQuantity *distanceQuantityConsumed = [HKQuantity quantityWithUnit:[HKUnit meterUnit] doubleValue:stepNum*0.5];
    HKQuantitySample *distanceConsumedSample = [HKQuantitySample quantitySampleWithType:distanceType quantity:distanceQuantityConsumed startDate:startDate endDate:endDate device:device metadata:nil];
    
    return @[stepConsumedSample];
}




@end
