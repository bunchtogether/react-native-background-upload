#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTLog.h>
#import <Photos/Photos.h>
#import "Reachability.h"
#import "QueuedUploadSession.h"
#import "Uploader.h"
#import "BackgroundUploadAppDelegate.h"

@interface Uploader ()

@property (nonatomic, strong) NSMutableDictionary *responsesData;
@property (nonatomic, strong) NSMutableDictionary *metrics;
@property (nonatomic, strong) NSOperationQueue *mainOperationQueue;
@property (nonatomic, strong) NSMutableOrderedSet *uploadIds;
@property (nonatomic, strong) NSMutableDictionary *operationQueues;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSession *backgroundSession;
@property (nonatomic, strong) Reachability *reach;
@property (nonatomic, assign) BOOL suspended;

@end

@implementation Uploader

+ (instancetype)sharedUploader{
    static Uploader *sharedUploader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedUploader = [[self alloc] init];
    });
    return sharedUploader;
}

+ (NSData *)normalizedJSONRequestBody:(id)body {
    return [NSJSONSerialization dataWithJSONObject:[self normalizeValue:body]
                                           options:NSJSONWritingPrettyPrinted
                                             error:nil];
}

+ (NSData *)dataForFile:(NSString *)path {
    NSURL *fileUri = [NSURL URLWithString:path];
    return [[NSFileManager defaultManager] contentsAtPath:[fileUri path]];
}

+ (NSString *)base64StringForFile:(NSString *)path {
    NSURL *fileUri = [NSURL URLWithString:path];
    NSString *filePath = [fileUri path];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    return [fileData base64EncodedStringWithOptions:0];
}

+ (id)normalizeValue:(id)value {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionaryValue = (NSDictionary*)value;
        NSMutableDictionary *normalizedDictionary = [NSMutableDictionary new];
        for (NSString *key in [dictionaryValue allKeys]) {
            normalizedDictionary[key] = [self normalizeValue:dictionaryValue[key]];
        }
        return normalizedDictionary;
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *arrayValue = (NSArray*)value;
        NSMutableArray *normalizedArray = [NSMutableArray new];
        for (id element in arrayValue) {
            [normalizedArray addObject:[self normalizeValue:element]];
        }
        return normalizedArray;
    } else if ([value isKindOfClass:[NSString class]]) {
        NSString *stringValue = (NSString*)value;
        if ([stringValue containsString:@"file://"]) {
            return [self base64StringForFile:stringValue];
        }
    }
    
    return value;
}

-(id) init {
    self = [super init];
    if (self) {
        self.responsesData = [NSMutableDictionary dictionary];
        self.metrics = [NSMutableDictionary dictionary];
        self.mainOperationQueue = [[NSOperationQueue alloc] init];
        self.mainOperationQueue.maxConcurrentOperationCount = 10;
        self.uploadIds = [[NSMutableOrderedSet alloc] init];
        self.operationQueues = [NSMutableDictionary dictionary];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray *ids = [defaults stringArrayForKey: @"backgroundUploads"];
#if (TARGET_IPHONE_SIMULATOR)
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSessionConfiguration *backgroundConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
#else
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSessionConfiguration *backgroundConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"ReactNativeBackgroundUpload"];
#endif
        config.allowsCellularAccess = YES;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.URLCache = nil;
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        config.timeoutIntervalForResource = 600.0;
        config.sessionSendsLaunchEvents = YES;
        config.shouldUseExtendedBackgroundIdleMode = YES;
        config.HTTPShouldUsePipelining = YES;
        config.waitsForConnectivity = NO;
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        backgroundConfig.allowsCellularAccess = YES;
        backgroundConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        backgroundConfig.URLCache = nil;
        backgroundConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        backgroundConfig.timeoutIntervalForResource = 600.0;
        backgroundConfig.sessionSendsLaunchEvents = YES;
        backgroundConfig.shouldUseExtendedBackgroundIdleMode = YES;
        backgroundConfig.HTTPShouldUsePipelining = YES;
        backgroundConfig.waitsForConnectivity = NO;
        self.backgroundSession = [NSURLSession sessionWithConfiguration:backgroundConfig delegate:self delegateQueue:nil];
        self.backgroundSession.sessionDescription = @"ReactNativeBackgroundUpload";
        self.suspended = NO;
        self.reach = [Reachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        [self.reach startNotifier];
        if(![self.reach isReachable]) {
            [self pauseDownloads];
        }
        for(NSString *uploadId in ids){
            NSDictionary *options = [defaults dictionaryForKey: uploadId];
            if(options) {
                [self enqueueUpload:uploadId options:options];
            } else {
                [self removeUpload:uploadId];
            }
        }
    }
    return self;
}

- (void)sendEventWithName:(NSString *)eventName body:(id)body
{
    NSDictionary* event = @{@"eventName": eventName, @"body": body};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"sendEventWithName" object:event];
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    if([self.reach isReachable]) {
        [self resumeDownloads];
    } else {
        [self pauseDownloads];
    }
}

- (void)pauseDownloads {
    if(self.suspended) {
        return;
    }
    NSLog(@"Uploader: pause");
    self.suspended = YES;
    self.mainOperationQueue.suspended = YES;
    for(UploadSessionOperation *operation in self.mainOperationQueue.operations) {
        if([operation isExecuting] && !operation.suspended) {
            [operation suspend];
        }
    }
    @synchronized(self.operationQueues) {
        NSOperationQueue *queue;
        for(NSString *queueId in self.operationQueues) {
            queue = [self.operationQueues objectForKey:queueId];
            queue.suspended = YES;
            for(UploadSessionOperation *operation in queue.operations) {
                if([operation isExecuting] && !operation.suspended) {
                    [operation suspend];
                }
            }
        }
    }
}

- (void)resumeDownloads {
    if(!self.suspended) {
        return;
    }
    NSLog(@"Uploader: resume");
    self.suspended = NO;
    self.mainOperationQueue.suspended = NO;
    for(UploadSessionOperation *operation in self.mainOperationQueue.operations) {
        if([operation isExecuting] && operation.suspended) {
            [operation resume];
        }
    }
    @synchronized(self.operationQueues) {
        NSOperationQueue *queue;
        for(NSString *queueId in self.operationQueues) {
            queue = [self.operationQueues objectForKey:queueId];
            queue.suspended = NO;
            for(UploadSessionOperation *operation in queue.operations) {
                if([operation isExecuting] && operation.suspended) {
                    [operation resume];
                }
            }
        }
    }
}

- (void)invalidate
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.session invalidateAndCancel];
    [self.backgroundSession invalidateAndCancel];
    [self.mainOperationQueue cancelAllOperations];
    @synchronized(self.operationQueues) {
        NSOperationQueue *queue;
        for(NSString *queueId in self.operationQueues) {
            queue = [self.operationQueues objectForKey:queueId];
            [queue cancelAllOperations];
        }
    }
    self.responsesData = nil;
    self.mainOperationQueue = nil;
    self.uploadIds = nil;
    self.operationQueues = nil;
    self.session = nil;
    self.backgroundSession = nil;
}


- (void) clearOperation:(NSString *)uploadId {
    NSOperationQueue *queue = self.mainOperationQueue;
    for(UploadSessionOperation *operation in queue.operations) {
        if([operation.uploadId isEqualToString:uploadId]) {
            [operation completeOperation];
            return;
        }
    }
    @synchronized(self.operationQueues) {
        NSMutableArray *queueIdsForRemoval = [NSMutableArray array];
        for(NSString *queueId in self.operationQueues) {
            queue = [self.operationQueues objectForKey:queueId];
            for(UploadSessionOperation *operation in queue.operations) {
                if([operation.uploadId isEqualToString:uploadId]) {
                    [operation completeOperation];
                    return;
                }
            }
            if(queue.operationCount == 0) {
                [queueIdsForRemoval addObject: queueId];
            }
        }
        for(NSString *queueId in queueIdsForRemoval) {
            [self.operationQueues removeObjectForKey: queueId];
        }
    }
    NSLog(@"No operation %@", uploadId);
}

/*
 Gets file information for the path specified.  Example valid path is: file:///var/mobile/Containers/Data/Application/3C8A0EFB-A316-45C0-A30A-761BF8CCF2F8/tmp/trim.A5F76017-14E9-4890-907E-36A045AF9436.MOV
 Returns an object such as: {mimeType: "video/quicktime", size: 2569900, exists: true, name: "trim.AF9A9225-FC37-416B-A25B-4EDB8275A625.MOV", extension: "MOV"}
 */
- (void) getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    @try {
        NSURL *fileUri = [NSURL URLWithString: path];
        NSString *pathWithoutProtocol = [fileUri path];
        NSString *name = [fileUri lastPathComponent];
        NSString *extension = [name pathExtension];
        bool exists = [[NSFileManager defaultManager] fileExistsAtPath:pathWithoutProtocol];
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: name, @"name", nil];
        [params setObject:extension forKey:@"extension"];
        [params setObject:[NSNumber numberWithBool:exists] forKey:@"exists"];
        
        if (exists)
        {
            [params setObject:[self guessMIMETypeFromFileName:name] forKey:@"mimeType"];
            NSError* error;
            NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:pathWithoutProtocol error:&error];
            if (error == nil)
            {
                unsigned long long fileSize = [attributes fileSize];
                [params setObject:[NSNumber numberWithLong:fileSize] forKey:@"size"];
            }
        }
        resolve(params);
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}

/*
 Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
 */
- (NSString *)guessMIMETypeFromFileName: (NSString *)fileName {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileName pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

/*
 Utility method to copy a PHAsset file into a local temp file, which can then be uploaded.
 */
- (void)copyAssetToFile: (NSString *)assetUrl completionHandler: (void(^)(NSString *__nullable tempFileUrl, NSError *__nullable error))completionHandler {
    NSURL *url = [NSURL URLWithString:assetUrl];
    PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil].lastObject;
    if (!asset) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"Asset could not be fetched.  Are you missing permissions?" forKey:NSLocalizedDescriptionKey];
        completionHandler(nil,  [NSError errorWithDomain:@"RNUploader" code:5 userInfo:details]);
        return;
    }
    PHAssetResource *assetResource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSURL *pathUrl = [NSURL fileURLWithPath:pathToWrite];
    NSString *fileURI = pathUrl.absoluteString;
    
    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;
    
    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:assetResource toFile:pathUrl options:options completionHandler:^(NSError * _Nullable e) {
        if (e == nil) {
            completionHandler(fileURI, nil);
        }
        else {
            completionHandler(nil, e);
        }
    }];
}

- (void)removeUpload: (NSString *)uploadId {
    if(!uploadId) {
        return;
    }
    [self clearOperation:uploadId];
    @synchronized(self.uploadIds) {
        [self.uploadIds removeObject:uploadId];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:uploadId];
        [defaults setObject:[self.uploadIds array] forKey:@"backgroundUploads"];
    }
}

- (void)enqueueUpload: (NSString *)uploadId options:(NSDictionary *)options {
    
    NSString *uploadUrl = options[@"url"];
    __block NSString *fileURI = options[@"path"];
    NSString *method = options[@"method"] ?: @"POST";
    NSString *uploadType = options[@"type"] ?: @"raw";
    NSString *fieldName = options[@"field"];
    NSDictionary *headers = options[@"headers"];
    NSDictionary *parameters = options[@"parameters"];
    NSString *queueId = options[@"queueId"];
    
    NSOperationQueue *queue = self.mainOperationQueue;
    if(!uploadId) {
        NSException* missingUploadIdException = [NSException
                                    exceptionWithName:@"MissingUploadIdException"
                                    reason:@"Missing required argument uploadId"
                                    userInfo:nil];
        @throw missingUploadIdException;
    }
    if(queueId) {
        @synchronized(self.operationQueues) {
            queue = self.operationQueues[queueId];
            if(!queue) {
                queue = [[NSOperationQueue alloc] init];
                queue.maxConcurrentOperationCount = 1;
                [self.operationQueues setObject:queue forKey:queueId];
            }
        }
    }
    
    NSURL *requestUrl = [NSURL URLWithString: uploadUrl];
    if (requestUrl == nil) {
        RCTLogError(@"RN Uploader: Request cannot be nil.");
        return [self removeUpload:uploadId];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
    [request setAllowsCellularAccess:YES];
    [request setHTTPMethod: method];
    [request setHTTPShouldUsePipelining:YES];
    
    [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull val, BOOL * _Nonnull stop) {
        if ([val respondsToSelector:@selector(stringValue)]) {
            val = [val stringValue];
        }
        if ([val isKindOfClass:[NSString class]]) {
            [request setValue:val forHTTPHeaderField:key];
        }
    }];
    
    // asset library files have to be copied over to a temp file.  they can't be uploaded directly
    if ([fileURI hasPrefix:@"assets-library"]) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        [self copyAssetToFile:fileURI completionHandler:^(NSString * _Nullable tempFileUrl, NSError * _Nullable error) {
            if (error) {
                dispatch_group_leave(group);
                RCTLogError(@"RN Uploader: Asset could not be copied to temp file.");
                return [self removeUpload:uploadId];
            }
            fileURI = tempFileUrl;
            dispatch_group_leave(group);
        }];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    }
    
    if([uploadType isEqualToString:@"multipart"] || [uploadType isEqualToString:@"raw"]) {
        NSString *path = [[NSURL URLWithString:fileURI] path];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if(!fileExists) {
            NSLog(@"RN Uploader: File does not exist %@.", path);
            return [self removeUpload:uploadId];
        }
    }
    NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithObjectsAndKeys:uploadId, @"id", nil];
    UploadSessionOperation *operation;
    if ([uploadType isEqualToString:@"multipart"]) {
        NSString *uuidStr = [[NSUUID UUID] UUIDString];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", uuidStr] forHTTPHeaderField:@"Content-Type"];
        NSData *httpBody = [self createBodyWithBoundary:uuidStr path:fileURI parameters: parameters fieldName:fieldName];
        [request setHTTPBody: httpBody];
        operation = [[UploadSessionOperation alloc] initWithSession:self.session backgroundSession:self.backgroundSession uploadId:uploadId request:request];
        [eventData setObject:[NSNumber numberWithInteger:httpBody.length] forKey:@"size"];
    } else if ([uploadType isEqualToString:@"json"]) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSData *httpBody = [Uploader normalizedJSONRequestBody:parameters];
        [request setHTTPBody:httpBody];
        operation = [[UploadSessionOperation alloc] initWithSession:self.session backgroundSession:self.backgroundSession uploadId:uploadId request:request];
        [eventData setObject:[NSNumber numberWithInteger:httpBody.length] forKey:@"size"];
    } else {
        if (parameters.count > 0) {
            RCTLogError(@"RN Uploader: Parameters supported only in 'multipart' and 'json' type");
            return [self removeUpload:uploadId];
        }
        operation = [[UploadSessionOperation alloc] initWithSession:self.session backgroundSession:self.backgroundSession uploadId:uploadId request:request fromFileUrl:[NSURL URLWithString:fileURI]];
        [eventData setObject:[NSNumber numberWithInteger:[[NSFileManager defaultManager] attributesOfItemAtPath:[[NSURL URLWithString:fileURI] path] error:nil].fileSize] forKey:@"size"];
    }
    if(queueId) {
        [eventData setObject:queueId forKey:@"queueId"];
    }
    [self sendEventWithName:@"RNFileUploader-initialize" body:eventData];
    [queue addOperation:operation];
    
    NSLog(@"Request: %@ | %@ | %p", requestUrl.absoluteString, uploadId, queue);
    if(queueId) {
        NSLog(@"Pending in queue %@ (%@): %lu", queueId, queue.suspended ? @"Suspended" : @"Active", queue.operationCount);
    } else {
        NSLog(@"Pending in main queue (%@): %lu", queue.suspended ? @"Suspended" : @"Active", queue.operationCount);
    }
}

/*
 * Starts a file upload.
 * Options are passed in as the first argument as a js hash:
 * {
 *   url: string.  url to post to.
 *   path: string.  path to the file on the device
 *   headers: hash of name/value header pairs
 * }
 *
 * Returns a promise with the string ID of the upload.
 */
- (void) startUpload:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    NSString *uploadId = [[[NSUUID UUID] UUIDString] lowercaseString];
    @synchronized(self.uploadIds) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:options forKey:uploadId];
        [self.uploadIds addObject:uploadId];
        [defaults setObject:[self.uploadIds array] forKey:@"backgroundUploads"];
    }
    [self enqueueUpload:uploadId options:options];
    resolve(uploadId);
}

/*
 * Cancels file upload
 * Accepts upload ID as a first argument, this upload will be cancelled
 * Event "cancelled" will be fired when upload is cancelled.
 */
- (void) cancelUpload: (NSString *)cancelUploadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    for(UploadSessionOperation *operation in self.mainOperationQueue.operations) {
        if([operation.uploadId isEqualToString:cancelUploadId]) {
            NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithObjectsAndKeys:operation.uploadId, @"id", nil];
            [self sendEventWithName:@"RNFileUploader-cancelled" body:eventData];
            [operation cancel];
            resolve([NSNumber numberWithBool:YES]);
            return;
        }
    }
    @synchronized(self.operationQueues) {
        NSOperationQueue *queue;
        for(NSString *queueId in self.operationQueues) {
            queue = [self.operationQueues objectForKey:queueId];
            BOOL cancelQueue = NO;
            for(UploadSessionOperation *operation in queue.operations) {
                if([operation.uploadId isEqualToString:cancelUploadId]) {
                    NSLog(@"Cancelling operations in queue %@ after individual cancellation of %@", queueId, operation.uploadId);
                    cancelQueue = YES;
                    break;
                }
            }
            if(cancelQueue) {
                for(UploadSessionOperation *operation in queue.operations) {
                    NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithObjectsAndKeys:operation.uploadId, @"id", nil];
                    [self sendEventWithName:@"RNFileUploader-cancelled" body:eventData];
                }
                [queue cancelAllOperations];
                resolve([NSNumber numberWithBool:YES]);
                return;
            }
        }
    }
    resolve([NSNumber numberWithBool:NO]);
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                              path:(NSString *)path
                        parameters:(NSDictionary *)parameters
                         fieldName:(NSString *)fieldName {
    
    NSMutableData *httpBody = [NSMutableData data];
    
    NSData *data = [Uploader dataForFile:path];
    NSString *filename  = [path lastPathComponent];
    NSString *mimetype  = [self guessMIMETypeFromFileName:path];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:data];
    [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return httpBody;
}


#pragma NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    float progress = -1;
    if (totalBytesExpectedToSend > 0) //see documentation.  For unknown size it's -1 (NSURLSessionTransferSizeUnknown)
    {
        progress = 100.0 * (float)totalBytesSent / (float)totalBytesExpectedToSend;
    }
    [self sendEventWithName:@"RNFileUploader-progress" body:@{ @"id": task.taskDescription, @"progress": [NSNumber numberWithFloat:progress] }];
    NSLog(@"Progress: %@, %@", [NSNumber numberWithFloat:progress], task.taskDescription);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data.length) {
        return;
    }
    //Hold returned data so it can be picked up by the didCompleteWithError method later
    NSMutableData *responseData = self.responsesData[@(dataTask.taskIdentifier)];
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
        self.responsesData[@(dataTask.taskIdentifier)] = responseData;
    } else {
        [responseData appendData:data];
    }
}
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    NSString *uploadId = task.taskDescription;
    if (!uploadId) {
        NSLog(@"No uploadId in task");
        return;
    }
    self.metrics[uploadId] = metrics;
    
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithObjectsAndKeys:task.taskDescription, @"id", nil];
    NSURLSessionDataTask *uploadTask = (NSURLSessionDataTask *)task;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)uploadTask.response;
    NSString *uploadId = task.taskDescription;
    
    if (!uploadId) {
        NSLog(@"No uploadId in task");
        return;
    }
    
    if (response) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        [eventData setObject:[NSNumber numberWithInteger:httpResponse.statusCode] forKey:@"responseCode"];
    }
    
    //Add data that was collected earlier by the didReceiveData method
    NSMutableData *responseData = self.responsesData[@(task.taskIdentifier)];
    if (responseData) {
        [self.responsesData removeObjectForKey:@(task.taskIdentifier)];
        NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        [eventData setObject:response forKey:@"responseBody"];
    } else {
        [eventData setObject:[NSNull null] forKey:@"responseBody"];
    }
    
    NSURLSessionTaskMetrics *metrics = self.metrics[uploadId];
    if (metrics) {
        [self.metrics removeObjectForKey:uploadId];
        [eventData setObject:@(metrics.taskInterval.duration) forKey:@"duration"];
    } else {
        [eventData setObject:[NSNull null] forKey:@"duration"];
    }
    
    NSLog(@"Completion handler %@: %@", uploadId, eventData);
    
    if (error == nil) {
        [self sendEventWithName:@"RNFileUploader-completed" body:eventData];
    } else {
        if (error.code == NSURLErrorCancelled) {
            NSLog(@"Upload %@ cancelled", uploadId);
            return;
        }
        NSLog(@"Upload error for %@: %@", uploadId, error.localizedDescription);
        for(UploadSessionOperation *operation in self.mainOperationQueue.operations) {
            if([operation.uploadId isEqualToString:uploadId] && [operation attempts] < 20) {
                [operation retry];
                return;
            }
        }
        @synchronized(self.operationQueues) {
            NSOperationQueue *queue;
            for(NSString *queueId in self.operationQueues) {
                queue = [self.operationQueues objectForKey:queueId];
                for(UploadSessionOperation *operation in queue.operations) {
                    if([operation.uploadId isEqualToString:uploadId] && [operation attempts] < 20) {
                        [operation retry];
                        return;
                    }
                }
            }
        }
        [eventData setObject:error.localizedDescription forKey:@"error"];
        [self sendEventWithName:@"RNFileUploader-error" body:eventData];
        // If the upload was part of a named queue, cancel the remaining items on failure
        @synchronized(self.operationQueues) {
            NSOperationQueue *queue;
            for(NSString *queueId in self.operationQueues) {
                queue = [self.operationQueues objectForKey:queueId];
                for(UploadSessionOperation *operation in queue.operations) {
                    if([operation.uploadId isEqualToString:uploadId]) {
                        NSLog(@"Cancelling operations in queue %@ after failure of %@", queueId, uploadId);
                        [queue cancelAllOperations];
                    }
                }
            }
        }
    }
    [self removeUpload:uploadId];
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BackgroundUploadAppDelegate *appDelegate = (BackgroundUploadAppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate.sessionCompletionHandlers && appDelegate.sessionCompletionHandlers[@"ReactNativeBackgroundUpload"]) {
            void (^completionHandler)() = appDelegate.sessionCompletionHandlers[@"ReactNativeBackgroundUpload"];
            [appDelegate.sessionCompletionHandlers removeObjectForKey:@"ReactNativeBackgroundUpload"];
            completionHandler();
            if([self.reach isReachable]) {
                [self resumeDownloads];
            } else {
                [self pauseDownloads];
            }
        }
    });
}

@end









