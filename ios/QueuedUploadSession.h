//
//  QueuedUploadSession.h
//  TRVSURLSessionOperation
//
// License: https://github.com/travisjeffery/TRVSURLSessionOperation/blob/master/LICENSE
//

#import <Foundation/Foundation.h>

@interface UploadSessionOperation : NSOperation

- (instancetype)initWithSession:(NSURLSession *)session backgroundSession:(NSURLSession *)backgroundSession uploadId:(NSString *)uploadId request:(NSURLRequest *)request;
- (instancetype)initWithSession:(NSURLSession *)session backgroundSession:(NSURLSession *)backgroundSession uploadId:(NSString *)uploadId request:(NSURLRequest *)request fromFileUrl:(NSURL *)fileURL;
- (void)completeOperation;
- (void)retry;
- (void)suspend;
- (void)resume;
- (int)attempts;

@property (nonatomic, copy) NSString *uploadId;
@property (nonatomic, assign) BOOL suspended;
@property (nonatomic, strong, readonly) NSURLSessionDataTask *task;

@end
