//
//  MFUtils.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 26.07.24.
//

#import "MFUtils.h"
#import "objc/runtime.h"

@implementation MFUtils

#pragma mark - objc inspection

NSString *listMethods(id obj) {
    
    /// This method prints a list of all methods defined on a class
    ///     (not its superclass) with decoded return types and argument types!
    ///     This is really handy for creating categories swizzles, or inspecting private classes.
    
    NSMutableString *result = [NSMutableString string];
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([obj class], &methodCount);
    
    [result appendFormat:@"Methods for %@:", NSStringFromClass([obj class])];
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        NSString *methodHeader = methodDescription(method);
        [result appendString:methodHeader];
    }
    
    free(methods);
    
    return result;
}

NSString *blockDescription(id block) {
    
    const char *typeEncoding = blockTypeEncoding(block);
    NSString *result = _methodDescription(@"(^)", typeEncoding);
    return result;
}

static const char *blockTypeEncoding(id blockObj) {
    
    /// Copied from: https://stackoverflow.com/a/10944983/10601702
    
    struct BlockDescriptor {
        unsigned long reserved;
        unsigned long size;
        void *rest[1];
    };

    struct Block {
        void *isa;
        int flags;
        int reserved;
        void *invoke;
        struct BlockDescriptor *descriptor;
    };
    
    struct Block *block = (__bridge void *)blockObj;
    struct BlockDescriptor *descriptor = block->descriptor;

    int copyDisposeFlag = 1 << 25;
    int signatureFlag = 1 << 30;

    assert(block->flags & signatureFlag);

    int index = 0;
    if(block->flags & copyDisposeFlag)
        index += 2;

    return descriptor->rest[index];
}

NSString *methodDescription(Method method) {
    
    SEL selector = method_getName(method);
    const char *typeEncoding = method_getTypeEncoding(method);
    NSString *result = _methodDescription(NSStringFromSelector(selector), typeEncoding);
    return result;
}

NSString *_methodDescription(NSString *methodName, const char *typeEncoding) {
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
    const char *returnType = [signature methodReturnType];
    long nOfArgs = [signature numberOfArguments];
    NSMutableArray *argTypes = [NSMutableArray array];
    for (int i = 2; i < nOfArgs; i++) { /// Start at 2 to skip the `self` and `_cmd` args
        const char *argType = [signature getArgumentTypeAtIndex:i];
        [argTypes addObject:typeNameFromEncoding(argType)];
    }
    
    NSString *fullMethodHeader = [NSString stringWithFormat:@"\n(%@)%@ (%@)", typeNameFromEncoding(returnType), methodName, [argTypes componentsJoinedByString:@", "]];
    
    return fullMethodHeader;
}

NSString *typeNameFromEncoding(const char *typeEncoding) { /// Credit ChatGPT & Claude
    
    NSMutableString *typeName = [NSMutableString string];
    NSUInteger index = 0;
    
    /// Handle type qualifiers
    while (typeEncoding[index] && strchr("rnNoORV^", typeEncoding[index])) {
        switch (typeEncoding[index]) {
            case 'r': [typeName appendString:@"const "]; break;
            case 'n': [typeName appendString:@"in "]; break;
            case 'N': [typeName appendString:@"inout "]; break;
            case 'o': [typeName appendString:@"out "]; break;
            case 'O': [typeName appendString:@"bycopy "]; break;
            case 'R': [typeName appendString:@"byref "]; break;
            case 'V': [typeName appendString:@"oneway "]; break;
            case '^': [typeName appendString:@"pointer "]; break;
        }
        index++;
    }
    
    /// Handle base type
    NSString *baseTypeName;
    switch (typeEncoding[index]) {
        case 'c': baseTypeName = @"char"; break;
        case 'i': baseTypeName = @"int"; break;
        case 's': baseTypeName = @"short"; break;
        case 'l': baseTypeName = @"long"; break;
        case 'q': baseTypeName = @"long long"; break;
        case 'C': baseTypeName = @"unsigned char"; break;
        case 'I': baseTypeName = @"unsigned int"; break;
        case 'S': baseTypeName = @"unsigned short"; break;
        case 'L': baseTypeName = @"unsigned long"; break;
        case 'Q': baseTypeName = @"unsigned long long"; break;
        case 'f': baseTypeName = @"float"; break;
        case 'd': baseTypeName = @"double"; break;
        case 'B': baseTypeName = @"bool"; break;
        case 'v': baseTypeName = @"void"; break;
        case '*': baseTypeName = @"char *"; break;
        case '@': baseTypeName = @"id"; break;
        case '#': baseTypeName = @"Class"; break;
        case ':': baseTypeName = @"SEL"; break;
        case '[': baseTypeName = @"array"; break;
        case '{': baseTypeName = @"struct"; break;
        case '(': baseTypeName = @"union"; break;
        case 'b': baseTypeName = @"bit field"; break;
        case '?': baseTypeName = @"unknown"; break;
        default:
            NSLog(@"typeEncoding: %s is unknown", typeEncoding);
            assert(false);
    }
    index++;
    
    if (index <= (strlen(typeEncoding) - 1) && typeEncoding[index-1] == '@' && typeEncoding[index] == '?') {
        baseTypeName = @"^block";
        index++;
    }
    
    /// Store name
    [typeName appendString:baseTypeName];
    
    /// Store any unhandled type information
    if (index <= (strlen(typeEncoding) - 1)) {
        NSString *fullTypeEncoding = [NSString stringWithUTF8String:typeEncoding];
        return [NSString stringWithFormat:@"%@ [%@]", typeName, fullTypeEncoding];
    } else {
        return typeName;
    }
}

@end
