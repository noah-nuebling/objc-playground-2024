//
//  MFDataClassClass.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 24.07.24.
//

#import "MFDataClass.h"
#import "objc/runtime.h"

@implementation MFDataClassBase

/// Factory

+ (instancetype)new {
    id newInstance = [[self alloc] init];
    return newInstance;
}

/// NSCoding protocol
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        for (NSString *key in self.allPropertyNames) {
            
            id value = [coder decodeObjectForKey:key];
            if (value) {
                [self setValue:value forKey:key];
            }
            
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    for (NSString *key in self.allPropertyNames) {
        id value = [self valueForKey:key];
        if (value) {
            [coder encodeObject:value forKey:key];
        }
    }

    
}
/// NSCopying Protocol
- (id)copyWithZone:(NSZone *)zone {
    MFDataClassBase *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
    
        for (NSString *key in self.allPropertyNames) {
            id value = [self valueForKey:key];
            if (value) {
                [copy setValue:[value copyWithZone:zone] forKey:key];
            }
        }
    }
    return copy;
}

/// Equality Check
- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    MFDataClassBase *other = (MFDataClassBase *)object;
    
    for (NSString *key in self.allPropertyNames) {
        id selfValue = [self valueForKey:key];
        id otherValue = [other valueForKey:key];
        if (selfValue != otherValue && ![selfValue isEqual:otherValue]) {
            return NO;
        }
    }
    
    return YES;
}

- (NSUInteger)hash {

    NSUInteger hash = 0;

    for (NSString *key in self.allPropertyNames) {
        id value = [self valueForKey:key];
        hash ^= [value hash];
    }
    
    return hash;
}

/// Utility
- (NSArray<NSString *> *)allPropertyNames {
    
    NSMutableArray *result = [NSMutableArray array];
    
    unsigned int propertyCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);
    
    for (i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if (propName) {
            [result addObject:(id)[NSString stringWithUTF8String:propName]];
        }
    }
    
    free(properties);
    
    return result;
}

@end
