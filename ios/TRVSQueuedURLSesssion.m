//
//  TRVSQueuedURLSesssion.m
//  TRVSURLSessionOperation
//
// License: https://github.com/travisjeffery/TRVSURLSessionOperation/blob/master/LICENSE
//

#import "TRVSQueuedURLSesssion.h"

#define TRVSKVOBlock(KEYPATH, BLOCK) \
[self willChangeValueForKey:KEYPATH]; \
BLOCK(); \
[self didChangeValueForKey:KEYPATH];

@implementation TRVSURLSessionOperation {
    BOOL _finished;
    BOOL _executing;
}

- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request {
    if (self = [super init]) {
        _task = [session uploadTaskWithRequest:request fromData:nil];
        _task.taskDescription = uploadId;
    }
    return self;
}

- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request fromFileUrl:(NSURL *)fileURL {
    if (self = [super init]) {
        _task = [session uploadTaskWithRequest:request fromFile:fileURL];
        _task.taskDescription = uploadId;
    }
    return self;
}

- (void)cancel {
    [super cancel];
    [self.task cancel];
}

- (void)start {
    if (self.isCancelled) {
        TRVSKVOBlock(@"isFinished", ^{ _finished = YES; });
        return;
    }
    TRVSKVOBlock(@"isExecuting", ^{
        [self.task resume];
        _executing = YES;
    });
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    _executing = NO;
    _finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
