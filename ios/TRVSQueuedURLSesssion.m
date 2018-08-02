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

@interface TRVSURLSessionOperation ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSURLSessionUploadTask *task;
@property (nonatomic, assign) int attempt;
@end

@implementation TRVSURLSessionOperation {
    BOOL _finished;
    BOOL _executing;
}

- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request {
    if (self = [super init]) {
        self.request = request;
        self.session = session;
        self.task = [session uploadTaskWithRequest:request fromData:nil];
        // Retry a failed background task if initial creation did not succeed
        if (!self.task && session.configuration.identifier) {
            for (NSUInteger attempts = 0; !self.task && attempts < 3; attempts++) {
                self.task = [session uploadTaskWithRequest:request fromData:nil];
            }
        }
        self.attempt = 0;
        self.task.taskDescription = uploadId;
        _executing = NO;
        _finished = NO;
    }
    return self;
}

- (NSString *)uploadId {
    return self.task.taskDescription;
}

- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request fromFileUrl:(NSURL *)fileURL {
    if (self = [super init]) {
        self.request = request;
        self.fileURL = fileURL;
        self.session = session;
        self.task = [session uploadTaskWithRequest:request fromFile:fileURL];
        // Retry a failed background task if initial creation did not succeed
        if (!self.task && session.configuration.identifier) {
            for (NSUInteger attempts = 0; !self.task && attempts < 3; attempts++) {
                self.task = [session uploadTaskWithRequest:request fromFile:fileURL];
            }
        }
        self.attempt = 0;
        self.task.taskDescription = uploadId;
        _executing = NO;
        _finished = NO;
    }
    return self;
}

- (void)retry {
    self.attempt++;
    NSLog(@"Retry attempt %d", self.attempt);
    NSString *uploadId = self.task.taskDescription;
    [self.task cancel];
    if(self.fileURL && self.request) {
        self.task = [self.session uploadTaskWithRequest:self.request fromFile:self.fileURL];
    } else if(self.request) {
        self.task = [self.session uploadTaskWithRequest:self.request fromData:nil];
    }
    self.task.taskDescription = uploadId;
    [self.task resume];
}

- (int)attempts {
    return self.attempt;
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
        NSLog(@"isExecuting %@", self.task.taskDescription);
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
