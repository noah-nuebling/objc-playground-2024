//
// --------------------------------------------------------------------------
// BiMap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BiMap<K, V> : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)setKey:(K)key andValue:(V)value;
- (void)removePairForKey:(K)key;
- (void)removePairForValue:(V)value;
- (V)valueForKey:(K)key;
- (K)keyForValue:(V)value;


@end

NS_ASSUME_NONNULL_END
