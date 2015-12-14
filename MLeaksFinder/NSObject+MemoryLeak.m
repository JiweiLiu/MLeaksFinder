//
//  NSObject+MemoryLeak.m
//  MLeaksFinder
//
//  Created by zeposhe on 12/12/15.
//  Copyright © 2015 zeposhe. All rights reserved.
//

#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>

static const void *const kViewStackKey = &kViewStackKey;

@implementation NSObject (MemoryLeak)

- (BOOL)willDealloc {
    NSString *className = NSStringFromClass([self class]);
    if ([[NSObject classNamesInWhiteList] containsObject:className])
        return NO;
    
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf assertNotDealloc];
    });
    
    return YES;
}

- (void)assertNotDealloc {
    NSString *className = NSStringFromClass([self class]);
    NSAssert(NO, @"Possibly Memory Leak.\nIn case that %@ should not be dealloced, override -assertNotDealloc in %@ by giving it an empty implementation.\nView-ViewController stack: %@", className, className, [self currentViewStack]);
}

- (NSArray *)currentViewStack {
    NSString *className = NSStringFromClass([self class]);
    NSArray *viewStack = objc_getAssociatedObject(self, kViewStackKey);
    if (viewStack) {
        viewStack = [viewStack arrayByAddingObject:className];
    } else {
        viewStack = @[ className ];
    }
    return viewStack;
}

- (void)setPreviousViewStack:(NSArray *)viewStack {
    objc_setAssociatedObject(self, kViewStackKey, viewStack, OBJC_ASSOCIATION_COPY);
}

+ (NSSet *)classNamesInWhiteList {
    static NSSet *whiteList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whiteList = [NSSet setWithObjects:
                     @"_UIAlertControllerActionView",
                     nil];
    });
    return whiteList;
}

#ifdef DEBUG

+ (void)swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL {
    Class class = [self class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSEL,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSEL,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

#endif

@end