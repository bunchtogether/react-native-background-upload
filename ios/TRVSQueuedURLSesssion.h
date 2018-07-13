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

@property (nonatomic, strong, readonly) NSURLSessionDataTask *task;

@end
