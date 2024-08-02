//
//  ObserveSelf.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 01.08.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KVOMutationSupportProxy<T> : NSProxy
- (instancetype)initWithObject:(T)object;
@end

@interface NSObject (MFKVOMutationSupport)
- (void)notifyOnMutation:(BOOL)doNotify; /// Should be thread safe, not sure.
@end


NS_ASSUME_NONNULL_END
