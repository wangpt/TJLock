//
//  ViewController.m
//  TJLock
//
//  Created by tao on 2018/9/10.
//  Copyright © 2018年 tao. All rights reserved.
//
/*
 可以看出要是没有优先级反转的问题的话，osspinlock占有绝对，其次就是dispatch_semaphore，dispatch_semaphore和os_unfair_lock差距很小，其次就是pthread_mutex。其实在测试的时候呢，性能和次数是有关系的，即是说这几种锁在不同的情形下会发挥最好性能，次数量大的时候呢，性能排名就如上面一样。所以在项目中使用的话，就根据项目情况选择即可。
 */
#import "ViewController.h"
//OSSpinLock
#import <libkern/OSAtomic.h>
//os_unfair_lock
#import <os/lock.h>
//pthread_mutex
#import <pthread.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    int buttonCount = 5;
    for (int i = 0; i < buttonCount; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, 0, 200, 50);
        button.center = CGPointMake(self.view.frame.size.width / 2, i * 60 + 160);
        button.tag = pow(10, i + 3);
        [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [button setTitle:[NSString stringWithFormat:@"run (%d)",(int)button.tag] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
}

- (void)tap:(UIButton *)sender {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self test:(int)sender.tag];
    });

}

- (void)test:(int)count {
    {
        //自旋锁
        [self osspinlock:count];
        [self os_unfair_lock:count];
    }
    
    {
        //信号量
        [self dispatch_semaphore:count];
    }
    
    {
        //互斥锁
        [self nslock:count];
        [self pthread_mutex:count];
        [self synchronized:count];
    }
    
    {
        //条件锁
        [self _NSCondition:count];
        [self _NSConditionLock:count];
    }
    {
        //递归锁
        [self _NSRecursiveLock:count];
        [self pthread_mutex_recursive:count];
    }
    
    {
        //读写锁
        [self pthread_rwlock:count];
    }

    printf("---- fin (%d) ----\n\n",count);
}
#pragma mark - 自旋锁
//对于内存缓存的存取来说，它非常合适
- (void)osspinlock:(int)count{
    NSTimeInterval begin, end;
    OSSpinLock lock = OS_SPINLOCK_INIT;
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        OSSpinLockLock(&lock);
        OSSpinLockUnlock(&lock);
    }
    end = CACurrentMediaTime();
    printf("OSSpinLock:               %8.2f ms\n", (end - begin) * 1000);
}
//iOS10之后替代OSSPinLock的锁，解决了优先级反转的问题
- (void)os_unfair_lock:(int)count{
    if (@available(iOS 10.0, *)) {
        NSTimeInterval begin, end;
        os_unfair_lock_t unfairLock;
        unfairLock = &(OS_UNFAIR_LOCK_INIT);
        begin = CACurrentMediaTime();
        for (int i = 0; i < count; i++) {
            os_unfair_lock_lock(unfairLock);
            os_unfair_lock_unlock(unfairLock);
        }
        end = CACurrentMediaTime();
        printf("os_unfair_lock:           %8.2f ms\n", (end - begin) * 1000);
    }
}
#pragma mark - 信号量（GCD）
- (void)dispatch_semaphore:(int)count{
    NSTimeInterval begin, end;
    dispatch_semaphore_t lock =  dispatch_semaphore_create(1);
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_signal(lock);
    }
    end = CACurrentMediaTime();
    printf("dispatch_semaphore:       %8.2f ms\n", (end - begin) * 1000);
}

#pragma mark - 互斥锁

- (void)nslock:(int)count{
    NSTimeInterval begin, end;
    NSLock *lock = [NSLock new];
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        [lock lock];
        [lock unlock];
    }
    end = CACurrentMediaTime();
    printf("NSLock:                   %8.2f ms\n", (end - begin) * 1000);
    
}

- (void)pthread_mutex:(int)count{
    NSTimeInterval begin, end;
    pthread_mutex_t lock;
    pthread_mutex_init(&lock, NULL);
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        pthread_mutex_lock(&lock);
        pthread_mutex_unlock(&lock);
    }
    end = CACurrentMediaTime();
    pthread_mutex_destroy(&lock);
    printf("pthread_mutex:            %8.2f ms\n", (end - begin) * 1000);
    
}

- (void)synchronized:(int)count{
    NSTimeInterval begin, end;
    NSObject *lock = [NSObject new];
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        @synchronized(lock) {}
    }
    end = CACurrentMediaTime();
    printf("@synchronized:            %8.2f ms\n", (end - begin) * 1000);
    
}
#pragma mark - 条件锁
- (void)_NSCondition:(int)count{
    NSTimeInterval begin, end;
    NSCondition *lock = [NSCondition new];
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        [lock lock];
        [lock unlock];
    }
    end = CACurrentMediaTime();
    printf("NSCondition:              %8.2f ms\n", (end - begin) * 1000);
}
//(条件锁、对象锁)
- (void)_NSConditionLock:(int)count{
    NSTimeInterval begin, end;
    NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:1];
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        [lock lock];
        [lock unlock];
    }
    end = CACurrentMediaTime();
    printf("NSConditionLock:          %8.2f ms\n", (end - begin) * 1000);
    
}
#pragma mark - 递归锁
- (void)_NSRecursiveLock:(int)count{
    NSTimeInterval begin, end;
    NSRecursiveLock *lock = [NSRecursiveLock new];
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        [lock lock];
        [lock unlock];
    }
    end = CACurrentMediaTime();
    printf("NSRecursiveLock:          %8.2f ms\n", (end - begin) * 1000);
}

- (void)pthread_mutex_recursive:(int)count{
    NSTimeInterval begin, end;
    pthread_mutex_t lock;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&lock, &attr);
    pthread_mutexattr_destroy(&attr);
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        pthread_mutex_lock(&lock);
        pthread_mutex_unlock(&lock);
    }
    end = CACurrentMediaTime();
    pthread_mutex_destroy(&lock);
    printf("pthread_mutex(recursive): %8.2f ms\n", (end - begin) * 1000);

}
#pragma mark - 读写锁
- (void)pthread_rwlock:(int)count{
    NSTimeInterval begin, end;
    pthread_rwlock_t rwlock;
    pthread_rwlock_init(&rwlock,NULL);
    begin = CACurrentMediaTime();
    for (int i = 0; i < count; i++) {
        pthread_rwlock_rdlock(&rwlock);
        pthread_rwlock_unlock(&rwlock);
    }
    end = CACurrentMediaTime();
    printf("pthread_rwlock:           %8.2f ms\n", (end - begin) * 1000);
}

@end
