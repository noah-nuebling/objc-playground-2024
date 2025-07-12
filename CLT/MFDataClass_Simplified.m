//
//  MFDataClass_Simplified.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 06.07.25.
//

/// 'Jul 6 2025] The MFDataClass implementation we have in MMF is totally overengineered to do NSSecureCoding automatically. What would a simplified version look like?

#import <Foundation/Foundation.h>
#import "objc/runtime.h"
#import "AppKit/AppKit.h"

#define auto __auto_type

@interface MFDataClassBase_Simplified : NSObject <NSCoding> @end

@implementation MFDataClassBase_Simplified


+ (NSArray<NSString *> *)ivarNames { /// This is called a lot and should perhaps be cached.
    
    NSMutableArray *result = [NSMutableArray array];
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList([self class], &ivarCount);
    
    for (Ivar *ivar = ivars; *ivar; ivar++) {
        const char *name = ivar_getName(*ivar);
        if (!name) { assert(false); continue; }
        auto nameNS = @(name);
        if (!nameNS) { assert(false); continue; }
        [result addObject: (id)nameNS];
    }
    
    free(ivars);
    
    return result;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    for (NSString *ivarName in [[self class] ivarNames]) {
        [coder encodeObject: [self valueForKey: ivarName] forKey: ivarName];
    }
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    for (NSString *ivarName in [[self class] ivarNames]) {
        [self setValue: [coder decodeObjectForKey: ivarName] forKey: ivarName];
    }
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    } else {
        for (NSString *ivarName in [[self class] ivarNames]) {
            id val1 = [self valueForKey: ivarName];
            id val2 = [other valueForKey: ivarName];
            if (!val1 && !val2) continue;
            if (![val1 isEqual: val2]) return NO;
        }
        return YES;
    }
}

- (NSUInteger)hash {
    return [[[self class] ivarNames] count]; /// NSDictionary needs hash to never change, that's why mutable object's `-[hash]` should not depend on internal state
}

- (NSString *)description {
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendString:@"{\n"];
    
    int i = 0;
    for (NSString *ivarName in [[self class] ivarNames]) {
        if (i) [result appendString: @",\n"];
        auto ivarDesc = [NSString stringWithFormat: @"%@: %@", ivarName, ([[self valueForKey: ivarName] description] ?: @"<null>")];
        ivarDesc = [ivarDesc stringByReplacingOccurrencesOfString: @"(^|\n)(.)" withString: @"$1    $2" options: NSRegularExpressionSearch range: NSMakeRange(0, ivarDesc.length)];
        [result appendString: ivarDesc];
        i++;
    }

    [result appendString:@"\n}"];

    return result;
}

@end

#define MFDataClassInterface(classname, superclassname, structfields) \
    @interface classname : superclassname { \
        @public                     \
        structfields;               \
    }                               \
    @end                            \
    typedef struct {                \
        structfields;               \
    } classname ## Structure;
    
#define MFDataClassImplement(classname, superclassname, structfields) \
    @implementation classname   \
    + (void) load {             \
        assert(sizeof(classname ## Structure) == class_getInstanceSize([classname class]) - sizeof(Class)); /** If this fails, our struct initializion hack won't work */\
    }                           \
    @end

#define MFDataClass(classname, superclassname, structfields)        \
    MFDataClassInterface(classname, superclassname, structfields)   \
    MFDataClassImplement(classname, superclassname, structfields)   \

#define MFDataClassMake(classname, initialvalues...) ({                         \
    _Pragma("clang diagnostic push")                                            \
    _Pragma("clang diagnostic error \"-Wmissing-field-initializers\"")          \
    _Pragma("clang diagnostic error \"-Wmissing-designated-field-initializers\"")   /** This apparently only works in C++ :( */\
    _Pragma("clang diagnostic warn \"-Winitializer-overrides\"")               \
    __auto_type _result = [[classname alloc] init];                             \
    classname ## Structure _initializer = {                                     \
        initialvalues                                                           \
    };                                                                          \
    void *_ivar_startptr = (((__bridge void *)_result) + sizeof(Class)); /** Skip over the isa pointer */ \
    *(typeof(_initializer) *)_ivar_startptr = _initializer;              /** Seems like ARC correctly retains the assigned objects here. Very hacky but should work as long as the struct fields and object's ivars have the exact same memory layout. */\
    _result;                                                                    \
    _Pragma("clang diagnostic pop");                                            \
});
        
        

MFDataClass(SimpleDataClass, MFDataClassBase_Simplified,
    int theint;
    NSString *_Nonnull thestr;
    bool istrue;
    NSObject *__strong theobj;
    bool isfalse;
    short isshort;
);

void MFDataClass_Simplified_Tests(void) {
    
    auto model = MFDataClassMake(SimpleDataClass,
        .theint=123,
        .thestr=@"abc",
        .theobj=@[@1, @"2", @3],
        .isfalse=true,
        .istrue=false,
        .isshort=INT16_MAX,
    );
    NSLog(@"The obj: %@", model);
    
    /// Archive
    NSError *err = nil;
    NSData *archive;
    {
        archive = [NSKeyedArchiver archivedDataWithRootObject: model requiringSecureCoding: NO error: &err];
        assert(!err);
    }
    
    /// Unarchive
    SimpleDataClass *reconstructed;
    {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData: archive error: &err];
        assert(!err);
        unarchiver.requiresSecureCoding = NO;
        reconstructed = [unarchiver decodeObjectForKey: NSKeyedArchiveRootObjectKey];
        
    }
    
    /// Print unarchived
    NSLog(@"Reconstructed: %@", reconstructed);
    
    /// Test equality
    {
        assert([model isEqual: reconstructed]);
        model->theint += 1;
        assert(![model isEqual: reconstructed]);
    }
    
    ///
    ///     Conclusion: This is pretty cool!
    ///         -> 100 loc to get the ease-of-use of structs with the power of objects!
    ///         -> Downsides vs our > 2000 loc main MFDataClass implementation:
    ///             - No NSSecureCoding support (but who needs that)
    ///             - Not 100% sure the MFDataClassMake is safe (relies on struct and ivars having exact same memory-layout.
    ///             - These dataclasses' state cannot be observed via KVO (would have to use properties I think)
    ///             -> I'll probably still stick with our ver
    
}


@implementation NSObject (MFDataClass_Simplified_LoadTests)

    + (void)load {
        MFDataClass_Simplified_Tests();
    }

@end
