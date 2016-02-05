
//  INSOperationsKitTests.m
//  INSOperationsKitTests
//
//  Created by Michal Zaborowski on 03.09.2015.
//  Copyright (c) 2015 Michal Zaborowski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
@import INSOperationsKit;
#import "INSOperationTestCondition.h"
#import "INSTestChainOperation.h"

@interface INSOperationsKitTests : XCTestCase
@property (nonatomic, strong) INSOperationQueue *operationQueue;
@end

@implementation INSOperationsKitTests

- (void)setUp {
    [super setUp];
    self.operationQueue = [[INSOperationQueue alloc] init];
}

- (void)tearDown {
    [super tearDown];
    [self.operationQueue cancelAllOperations];
    self.operationQueue = nil;
}

- (void)testStandardOperation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        [expectation fulfill];
    }];
    
    [self.operationQueue addOperation:operation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOperationCompletionBlock {
    XCTestExpectation *executingExpectation = [self expectationWithDescription:@"executingExpectation"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completionExpectation"];
    
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        [executingExpectation fulfill];
    }];
    
    [operation ins_addCompletionBlock:^(NSOperation *operation){
       [completionExpectation fulfill]; 
    }];
    
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBlockOperationWithNoConditionsAndNoDependencies {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        completionBlock();
    }];
    
    [self.operationQueue addOperation:operation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBlockOperationWithPassingConditionsAndNoDependencies {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        completionBlock();
    }];
    
    [operation addCondition:[[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return YES;
    }]];
    [self.operationQueue addOperation:operation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBlockOperationWithFailingConditionsAndNoDependencies {

    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"Should not have run the block operation");
    }];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    XCTAssertFalse(operation.cancelled, @"Should not yet have cancelled the operation");
    
    [operation addCondition:[[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return NO;
    }]];
    [self.operationQueue addOperation:operation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBlockOperationWithPassingConditionsAndConditionDependencyAndNoDependencies {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    NSMutableArray *fulfilledExpectations = [NSMutableArray array];
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        [fulfilledExpectations addObject:expectation];
        completionBlock();
    }];
    
    INSOperationTestCondition *condition = [[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return YES;
    }];
    condition.dependencyOperation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation2 fulfill];
        [fulfilledExpectations addObject:expectation2];
        completionBlock();
    }];
    
    [operation addCondition:condition];
    [self.operationQueue addOperation:operation];
    
    NSArray *expectations = @[expectation,expectation2];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertEqual(fulfilledExpectations.count, expectations.count, @"Expectations fulfilled out of order");
    }];
}

- (void)testOperationWithNoConditionsAndHasDependency {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectationDependency = [self expectationWithDescription:@"block2"];
    
    NSMutableArray *fulfilledExpectations = [NSMutableArray array];
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        [fulfilledExpectations addObject:expectation];
        completionBlock();
    }];
    
    INSBlockOperation *operationDependency = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectationDependency fulfill];
        [fulfilledExpectations addObject:expectationDependency];
        completionBlock();
    }];
    
    [operation addDependency:operationDependency];
    
    [self.operationQueue addOperation:operation];
    [self.operationQueue addOperation:operationDependency];
    
    NSArray *expectations = @[expectation,expectationDependency];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertEqual(fulfilledExpectations.count, expectations.count, @"Expectations fulfilled out of order");
    }];
}

- (void)testBlockOperationMissingCompletionBlockWithNoConditionsAndHasDependency {
    XCTestExpectation *expectationDependency = [self expectationWithDescription:@"block"];

    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"Should not have run the block operation,");
    }];
    
    INSBlockOperation *operationDependency = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectationDependency fulfill];
    }];
    
    [operation addDependency:operationDependency];
    
    [self.operationQueue addOperation:operation];
    [self.operationQueue addOperation:operationDependency];
    

    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertNotEqual(operationDependency.state, INSOperationStateFinished, @"Expectations fulfilled out of order");
    }];
}

- (void)testGroupOperation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    NSOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        [expectation fulfill];
    }];
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        [expectation2 fulfill];
    }];
    
    INSGroupOperation *groupOperation = [[INSGroupOperation alloc] initWithOperations:@[operation1,operation2]];
    
    [self keyValueObservingExpectationForObject:groupOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:groupOperation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testGroupOperationCancelBeforeExecuting {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    NSOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    operation1.completionBlock = ^{
        [expectation fulfill];
    };
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    operation2.completionBlock = ^{
        [expectation2 fulfill];
    };
    
    INSGroupOperation *groupOperation = [[INSGroupOperation alloc] initWithOperations:@[operation1,operation2]];
    
    [self keyValueObservingExpectationForObject:groupOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    self.operationQueue.suspended = YES;
    [self.operationQueue addOperation:groupOperation];
    [groupOperation cancel];
    self.operationQueue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDelayOperation {
    NSTimeInterval delay = 0.1f;
    
    NSDate *now = [NSDate date];
    INSDelayOperation *delayOperation = [[INSDelayOperation alloc] initWithDelay:delay];
    
    [self keyValueObservingExpectationForObject:delayOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    [self.operationQueue addOperation:delayOperation];
    [self waitForExpectationsWithTimeout:delay+1.0 handler:^(NSError *error) {
        XCTAssertTrue([[NSDate date] timeIntervalSinceDate:now] >= delay, "Didn't delay long enough");
    }];
}

- (void)testMutalExclusion {
    XCTestExpectation *expectation = [self expectationWithDescription:@"operation"];
    __block BOOL running = NO;
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        running = YES;
        [expectation fulfill];
        completionBlock();
    }];
    
    INSMutallyExclusiveCondition *mutallyExclusiveCondition = [INSMutallyExclusiveCondition mutualExclusiveForClass:[INSBlockOperation class]];
    [operation addCondition:mutallyExclusiveCondition];
    
    self.operationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    
    INSDelayOperation *delayOperation = [[INSDelayOperation alloc] initWithDelay:0.1];
    [delayOperation addCondition:mutallyExclusiveCondition];
    
    [self keyValueObservingExpectationForObject:delayOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        XCTAssertFalse(running, @"delay operation should not yet have started execution");
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:delayOperation];
    [self.operationQueue addOperation:operation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSilientConditionFailure {
    INSOperationTestCondition *testCondition = [[INSOperationTestCondition alloc] initWithConditionBlock:nil];
    
    testCondition.dependencyOperation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"should not run");
        completionBlock();
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"operation"];
    
    testCondition.block = ^BOOL() {
        [expectation fulfill];
        return NO;
    };
    
    INSSilientCondition *silientCondition = [INSSilientCondition silientConditionForCondition:testCondition];
    
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"should not run");
        completionBlock();
    }];
    
    [operation addCondition:silientCondition];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testNegateConditionFailure {
    
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"should not run");
        completionBlock();
    }];
    
    INSOperationTestCondition *testCondition = [[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return YES;
    }];
    
    INSNegatedCondition *negatedCondition = [INSNegatedCondition negatedConditionForCondition:testCondition];
    [operation addCondition:negatedCondition];
    
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testNegateConditionSuccess {
    XCTestExpectation *expectation = [self expectationWithDescription:@"operation"];
    
    INSBlockOperation *operation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        completionBlock();
    }];
    
    INSOperationTestCondition *testCondition = [[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return NO;
    }];
    
    INSNegatedCondition *negatedCondition = [INSNegatedCondition negatedConditionForCondition:testCondition];
    [operation addCondition:negatedCondition];
    
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testNoCancelledDependenciesCondition {
    __block INSBlockOperation *dependencyOperation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [dependencyOperation cancel];
        completionBlock();
    }];
    
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"shouldn't run");
        completionBlock();
    }];
    
    INSNoCancelledDependenciesCondition *noCancelledCondition = [[INSNoCancelledDependenciesCondition alloc] init];
    [operation addCondition:noCancelledCondition];
    
    [self keyValueObservingExpectationForObject:dependencyOperation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:self.operationQueue keyPath:@"operationCount" handler:^BOOL(INSOperationQueue *observedObject, NSDictionary *change) {
        return observedObject.operationCount == 0;
    }];
    
    [operation addDependency:dependencyOperation];
    
    [self.operationQueue addOperation:operation];
    [self.operationQueue addOperation:dependencyOperation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOperationsRunsEvenWhenDependencyCancelled {
    __block INSBlockOperation *dependencyOperation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [dependencyOperation cancel];
        completionBlock();
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"operation"];
    
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        completionBlock();
    }];
    
    [self keyValueObservingExpectationForObject:dependencyOperation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];

    [operation addDependency:dependencyOperation];
    
    [self.operationQueue addOperation:operation];
    [self.operationQueue addOperation:dependencyOperation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testNoCancelledDependenciesConditionAndDependenciesCancelsInGroupOperation {
    __block INSBlockOperation *dependencyOperation = [[INSBlockOperation alloc] initWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [dependencyOperation cancel];
        completionBlock();
    }];
    
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"shouldn't run");
        completionBlock();
    }];
    
    INSNoCancelledDependenciesCondition *noCancelledCondition = [[INSNoCancelledDependenciesCondition alloc] init];
    [operation addCondition:noCancelledCondition];
    [operation addDependency:dependencyOperation];
    
    INSGroupOperation *groupOperation = [INSGroupOperation operationWithOperations:@[dependencyOperation,operation]];
    
    [self keyValueObservingExpectationForObject:dependencyOperation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:groupOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.isFinished;
    }];
    
    [self.operationQueue addOperation:groupOperation];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertEqual(self.operationQueue.operationCount, 0, "");
    }];
}

- (void)testCancelOperationAndCancelBeforeStart {
    INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"This should not run");
        completionBlock();
    }];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    self.operationQueue.suspended = YES;
    [self.operationQueue addOperation:operation];
    [operation cancel];
    self.operationQueue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertTrue(operation.cancelled);
        XCTAssertTrue(operation.finished);
    }];
}

- (void)testCancelOperationAndCancelAfterStart {
    XCTestExpectation *expectation = [self expectationWithDescription:@"operation"];
    
    __block INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [operation cancel];
        [expectation fulfill];
        completionBlock();
    }];
    
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        XCTAssertEqual(self.operationQueue.operationCount, 0);
    }];
}

- (void)testBlockObserver {
    __block INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [operation produceOperation:[INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
            completionBlock();
        }]];
        completionBlock();
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"expectation"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"expectation2"];
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"expectation3"];
    
    INSBlockObserver *observer = [[INSBlockObserver alloc] initWithWillStartHandler:nil didStartHandler:^(INSOperation *operation) {
        [expectation fulfill];
        
    } produceHandler:^(INSOperation *operation, NSOperation *producedOperation) {
        [expectation2 fulfill];
        
    } finishHandler:^(INSOperation *operation, NSArray *errors) {
        [expectation3 fulfill];
    }];
    
    [operation addObserver:observer];
    [self.operationQueue addOperation:operation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testTimeoutObserver {
    INSDelayOperation *delayOperation = [INSDelayOperation operationWithDelay:1.0];
    INSTimeoutObserver *timeoutObserver = [[INSTimeoutObserver alloc] initWithTimeout:0.1];
    
    [delayOperation addObserver:timeoutObserver];
    
    [self keyValueObservingExpectationForObject:delayOperation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.isCancelled;
    }];
    [self.operationQueue addOperation:delayOperation];
    [self waitForExpectationsWithTimeout:0.9 handler:nil];
}

- (void)testChainCondition {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];

    INSBlockOperation *operation1 = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        completionBlock();
        [expectation fulfill];
    }];
    
    INSBlockOperation *operation2 = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        completionBlock();
        [expectation2 fulfill];
    }];

    [operation1 chainWithOperation:operation2];
    
    [self keyValueObservingExpectationForObject:operation2 keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:operation1];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testChainOperation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    NSOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        [expectation fulfill];
    }];
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        [expectation2 fulfill];
    }];
    
    INSChainOperation *chainOperation = [[INSChainOperation alloc] initWithOperations:@[operation1,operation2]];
    
    [self keyValueObservingExpectationForObject:chainOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:chainOperation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testChainOperationCancelBeforeExecuting {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    NSOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    operation1.completionBlock = ^{
        [expectation fulfill];
    };
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    operation2.completionBlock = ^{
        [expectation2 fulfill];
    };
    
    INSChainOperation *groupOperation = [[INSChainOperation alloc] initWithOperations:@[operation1,operation2]];
    
    [self keyValueObservingExpectationForObject:groupOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    self.operationQueue.suspended = YES;
    [self.operationQueue addOperation:groupOperation];
    [groupOperation cancel];
    self.operationQueue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testChainOperationShouldCancelWithErrorWhenMiddleOperationFail {
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    __block INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        [expectation fulfill];
        [operation finishWithError:[NSError errorWithDomain:@"error" code:1 userInfo:@{}]];
        completionBlock();
    }];
    
    INSChainOperation *chainOperation = [[INSChainOperation alloc] initWithOperations:@[operation,operation2]];
    
    [self keyValueObservingExpectationForObject:chainOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self keyValueObservingExpectationForObject:operation2 keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:chainOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:chainOperation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testChainOperationShouldCancelWithErrorWhenConditionFail {
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        XCTFail(@"should not execute -- cancelled");
    }];
    
    __block INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        XCTFail(@"should not execute -- cancelled");
    }];
    
    [operation addCondition:[[INSOperationTestCondition alloc] initWithConditionBlock:^BOOL{
        return NO;
    }]];
    
    INSChainOperation *chainOperation = [[INSChainOperation alloc] initWithOperations:@[operation,operation2]];
    
    [self keyValueObservingExpectationForObject:chainOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self keyValueObservingExpectationForObject:operation keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self keyValueObservingExpectationForObject:operation2 keyPath:@"isCancelled" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.cancelled;
    }];
    
    [self.operationQueue addOperation:chainOperation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testChainOperationDependencies {
    
    NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        
    }];
    
    __block INSBlockOperation *operation = [INSBlockOperation operationWithBlock:^(INSBlockOperationCompletionBlock completionBlock) {
        completionBlock();
    }];
    
    __unused INSChainOperation *chainOperation = [[INSChainOperation alloc] initWithOperations:@[operation,operation2]];
    
    XCTAssertTrue([operation2.dependencies containsObject:operation]);
}

- (void)testChainOperationDataPassing {
    NSDictionary *dict = @{};
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"block"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"block2"];
    
    INSTestChainOperation *operation = [INSTestChainOperation operationWithAdditionalDataToPass:^id{
        return dict;
    } operationFinishBlock:nil];
    operation.block = ^(INSBlockOperationCompletionBlock block) {
        [expectation fulfill];
        block();
    };
    
    INSTestChainOperation *operation2 = [INSTestChainOperation operationWithAdditionalDataToPass:nil operationFinishBlock:^(NSOperation *finishedOperation, NSArray<NSError *> *errors, id additionalDataReceived) {
        XCTAssertEqual(finishedOperation, operation);
        XCTAssertEqual(additionalDataReceived, dict);
    }];
    operation2.block = ^(INSBlockOperationCompletionBlock block) {
        [expectation2 fulfill];
        block();
    };
    
    INSChainOperation *chainOperation = [[INSChainOperation alloc] initWithOperations:@[operation,operation2]];
    
    [self keyValueObservingExpectationForObject:chainOperation keyPath:@"isFinished" handler:^BOOL(INSBlockOperation *observedObject, NSDictionary *change) {
        return observedObject.finished;
    }];
    
    [self.operationQueue addOperation:chainOperation];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
