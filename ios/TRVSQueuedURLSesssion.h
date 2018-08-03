//
//  TRVSQueuedURLSesssion.h
//  TRVSURLSessionOperation
//
// License: https://github.com/travisjeffery/TRVSURLSessionOperation/blob/master/LICENSE
//

#import <Foundation/Foundation.h>

@interface TRVSURLSessionOperation : NSOperation

- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request;
- (instancetype)initWithSession:(NSURLSession *)session uploadId:(NSString *)uploadId request:(NSURLRequest *)request fromFileUrl:(NSURL *)fileURL;
- (void)completeOperation;
- (void)retry;
- (int)attempts;

@property (nonatomic, copy) NSString *uploadId;
@property (nonatomic, strong, readonly) NSURLSessionDataTask *task;

@end
