//
//  MFDataClassClass.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 24.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Macros

/// Macros for user

#define MFDataClass(__className, __classProperties) \
    MFDataClassHeader(__className, __classProperties) \
    MFDataClassImplementation(__className) \

#define MFDataClassHeader(__className, __classProperties) \
    @interface __className : MFDataClassBase \
    UNPACK __classProperties \
    @end

#define MFDataProp(__typeAndName) \
    @property (nonatomic, strong, readwrite, nullable) __typeAndName;

/// Core Macros
///     Probably only used by other macros

#define MFDataClassImplementation(__className) \
    @implementation __className \
    @end

/// Helper macros
///     To implement the other macros

#define UNPACK(args...) args

#pragma mark - Base superclass

@interface MFDataClassBase : NSObject<NSCopying, NSCoding>

@end


NS_ASSUME_NONNULL_END
