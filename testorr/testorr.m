//
//  testorr.m
//  testorr
//
//  Created by Noah Nübling on 26.07.24.
//

#import <XCTest/XCTest.h>

@interface testorr : XCTestCase

@end

@implementation testorr

- (void)testStuff {

    
    XCUIScreenshot *screenshot = [[XCUIScreen mainScreen] screenshot];
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot quality:XCTImageQualityMedium];
    
    NSLog(@"Testing stuff!");
}


@end
