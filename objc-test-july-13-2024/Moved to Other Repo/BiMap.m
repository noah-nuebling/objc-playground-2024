//
// --------------------------------------------------------------------------
// BiMap.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "BiMap.h"

@implementation BiMap {
    
    NSMutableDictionary *_forwardMap;
    NSMutableDictionary *_backwardMap;
}

/// Init

- (instancetype)init
{
    self = [super init];
    if (self) {
        _forwardMap = [NSMutableDictionary dictionary];
        _backwardMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    
    BiMap *result = [self init];
    result->_forwardMap = dict.mutableCopy;
    
    for (id key in dict.allKeys) {
        id value = dict[key];
        result->_backwardMap[value] = key;
    }
    
    return self;
}

/// Setter

- (void)setKey:(id)key andValue:(id)value {
    _forwardMap[key] = value;
    _backwardMap[value] = key;
}

/// Deletors

- (void)removePairForKey:(id)key {
    id value = _forwardMap[key];
    _forwardMap[key] = nil;
    _backwardMap[value] = nil;
}
- (void)removePairForValue:(id)value {
    id key = _backwardMap[value];
    _forwardMap[key] = nil;
    _backwardMap[value] = nil;
}

/// Getters

- (id)valueForKey:(id)key {
    return _forwardMap[key];
}
- (id)keyForValue:(id)value {
    return _backwardMap[value];
}


@end
