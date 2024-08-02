//
//  main.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 13.07.24.
//

#import <Foundation/Foundation.h>
@import ObjectiveC.runtime;
#import "AppKit/AppKit.h"
#import "MFDataClass.h"
#import "ObserveBenchmarks.h"

MFDataClass(MFAddress, (MFDataProp(NSString *city)
                        MFDataProp(NSString *street)
                        MFDataProp(NSString *zipcode)))

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSLog(@"------------------");
        NSLog(@"BlockObserver Bench:");
        NSLog(@"------------------");
        
        runBlockObserverBenchmarks();
        
        NSLog(@"------------------");
        NSLog(@"GET INSTANCE METHOD TESTS:");
        NSLog(@"------------------");
        
        id class = [NSView class];
        id metaclass = object_getClass(class);
        
        NSLog(@"instance method alloc (class) %p",          class_getInstanceMethod(class, @selector(alloc)));
        NSLog(@"instance method alloc (meta) %p",           class_getInstanceMethod(metaclass, @selector(alloc)));
        NSLog(@"");
        NSLog(@"class method alloc (class) %p",             class_getClassMethod(class, @selector(alloc)));
        NSLog(@"class method alloc (meta) %p",              class_getClassMethod(metaclass, @selector(alloc)));
        NSLog(@"");
        NSLog(@"instance method addSubview: (class) %p",    class_getInstanceMethod(class, @selector(addSubview:)));
        NSLog(@"instance method addSubview: (meta) %p",     class_getInstanceMethod(metaclass, @selector(addSubview:)));
        NSLog(@"------------------");
        NSLog(@"SELECTOR RESPOND TESTS:");
        NSLog(@"------------------");
        NSLog(@"responds to alloc (class) %d", class_respondsToSelector(class, @selector(alloc)));
        NSLog(@"responds to alloc (meta) %d", class_respondsToSelector(metaclass, @selector(alloc)));
        NSLog(@"");
        NSLog(@"responds to init (class) %d", class_respondsToSelector(class, @selector(init)));
        NSLog(@"responds to init (meta) %d", class_respondsToSelector(metaclass, @selector(init)));
        NSLog(@"");
        NSLog(@"responds to addSubview: (class) %d", class_respondsToSelector(class, @selector(addSubview:)));
        NSLog(@"responds to addSubview: (meta) %d", class_respondsToSelector(metaclass, @selector(addSubview:)));
        NSLog(@"------------------");
        NSLog(@"(isel) responds to alloc (class) %d", [class instancesRespondToSelector:@selector(alloc)]);
        NSLog(@"(isel) responds to alloc (meta) %d", [metaclass instancesRespondToSelector:@selector(alloc)]);
        NSLog(@"");
        NSLog(@"(isel) responds to init (class) %d", [class instancesRespondToSelector:@selector(init)]);
        NSLog(@"(isel) responds to init (meta) %d", [metaclass respondsToSelector:@selector(init)]);
        NSLog(@"");
        NSLog(@"(isel) responds to addSubview: (class) %d", [class instancesRespondToSelector:@selector(addSubview:)]);
        NSLog(@"(isel) responds to addSubview: (meta) %d", [metaclass instancesRespondToSelector:@selector(addSubview:)]);
        NSLog(@"-------------------");
        NSLog(@"(sel) responds to alloc (class) %d", [class respondsToSelector:@selector(alloc)]);
        NSLog(@"(sel) responds to alloc (meta) %d", [metaclass respondsToSelector:@selector(alloc)]);
        NSLog(@"");
        NSLog(@"(sel) responds to init (class) %d", [class respondsToSelector:@selector(init)]);
        NSLog(@"(sel) responds to init (meta) %d", [metaclass respondsToSelector:@selector(init)]);
        NSLog(@"");
        NSLog(@"(sel) responds to addSubview: (class) %d", [class respondsToSelector:@selector(addSubview:)]);
        NSLog(@"(sel) responds to addSubview: (meta) %d", [metaclass respondsToSelector:@selector(addSubview:)]);
        NSLog(@"");
        
        NSLog(@"------------------");
        NSLog(@"MFDataClass tests:");
        NSLog(@"------------------");
    
        
        MFAddress *someData = [MFAddress new];
        someData.city = @"New Orleans";
        someData.street = @"abc street";
        someData.zipcode = @"68 NICE";
        
        NSData *someArchive = [NSKeyedArchiver archivedDataWithRootObject:someData requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:someArchive error:nil];
        unarchiver.requiresSecureCoding = NO;
        MFAddress *someUnarchivedData = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        
        MFAddress *someEquivalentData = [MFAddress new];
        someEquivalentData.city = @"New Orleans";
        someEquivalentData.street = @"abc street";
        someEquivalentData.zipcode = @"68 NICE";
        
        MFAddress *someOtherData = [MFAddress new];
        someOtherData.city = @"New York";
        someOtherData.street = @"xyz street";
        someOtherData.zipcode = @"70 NICE";
        
        NSLog(@"someData == someData.copy: %d", [someData isEqual:someData.copy]);
        NSLog(@"someData.copy == someEquivalentData: %d", [someData.copy isEqual:someEquivalentData]);
        NSLog(@"someData.copy == someOtherData: %d", [someData.copy isEqual:someOtherData]);
        
        NSLog(@"someUnarchivedData == someData: %d", [someUnarchivedData isEqual:someData]);
        NSLog(@"someUnarchivedData == someOtherData: %d", [someUnarchivedData isEqual:someOtherData]);
        
//        NSLog(@"macro test: %s", );
        
    }
    return 0;
}


