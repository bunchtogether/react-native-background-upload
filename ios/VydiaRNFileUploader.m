#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>
#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>
#import "TRVSQueuedURLSesssion.h"

@interface VydiaRNFileUploader : RCTEventEmitter <RCTBridgeModule, NSURLSessionTaskDelegate>
{
    NSMutableDictionary *_responsesData;
    NSOperationQueue *_mainOperationQueue;
    NSMutableOrderedSet *_uploadIds;
    NSMutableDictionary *_operationQueues;
    NSMutableDictionary *_operations;
}

@end

extern NSString *const FILE_PREFIX = @"file://";

@implementation VydiaRNFileUploader

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;
static RCTEventEmitter* staticEventEmitter = nil;
static NSString *BACKGROUND_SESSION_ID = @"ReactNativeBackgroundUpload";

+ (BOOL)requiresMainQueueSetup {
    return NO;
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
        if ([stringValue containsString:FILE_PREFIX]) {
            return [self base64StringForFile:stringValue];
        }
    }
    
    return value;
}

-(id) init {
    self = [super init];
    if (self) {
        staticEventEmitter = self;
        _responsesData = [NSMutableDictionary dictionary];
        _mainOperationQueue = [[NSOperationQueue alloc] init];
        _mainOperationQueue.maxConcurrentOperationCount = 1;
        _uploadIds = [[NSMutableOrderedSet alloc] init];
        _operationQueues = [[NSMutableDictionary alloc] init];
        _operations = [[NSMutableDictionary alloc] init];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray *ids = [defaults stringArrayForKey: @"backgroundUploads"];
        dispatch_async(dispatch_get_main_queue(), ^{
            for(NSString *uploadId in ids){
                NSDictionary *options = [defaults dictionaryForKey: uploadId];
                if(options) {
                    [self enqueueUpload:uploadId options:options];
                } else {
                    [self removeUpload:uploadId];
                }
            }
        });
    }
    return self;
}

- (void)_sendEventWithName:(NSString *)eventName body:(id)body {
    if (staticEventEmitter == nil)
        return;
    [staticEventEmitter sendEventWithName:eventName body:body];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
             @"RNFileUploader-progress",
             @"RNFileUploader-error",
             @"RNFileUploader-cancelled",
             @"RNFileUploader-completed"
             ];
}

/*
 Gets file information for the path specified.  Example valid path is: file:///var/mobile/Containers/Data/Application/3C8A0EFB-A316-45C0-A30A-761BF8CCF2F8/tmp/trim.A5F76017-14E9-4890-907E-36A045AF9436.MOV
 Returns an object such as: {mimeType: "video/quicktime", size: 2569900, exists: true, name: "trim.AF9A9225-FC37-416B-A25B-4EDB8275A625.MOV", extension: "MOV"}
 */
RCT_EXPORT_METHOD(getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
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
    [_uploadIds removeObject:uploadId];
    TRVSURLSessionOperation *operation = _operations[uploadId];
    if(operation){
        [operation completeOperation];
    }
    [_operations removeObjectForKey:uploadId];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:uploadId];
    [defaults setObject:[_uploadIds array] forKey:@"backgroundUploads"];
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
    
    NSOperationQueue *queue = _mainOperationQueue;
    
    if(queueId) {
        queue = _operationQueues[queueId];
        if(!queue) {
            queue = [[NSOperationQueue alloc] init];
            queue.maxConcurrentOperationCount = 1;
            [_operationQueues setObject:queue forKey:queueId];
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
    
    TRVSURLSessionOperation *operation;
    
    if ([uploadType isEqualToString:@"multipart"]) {
        NSString *uuidStr = [[NSUUID UUID] UUIDString];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", uuidStr] forHTTPHeaderField:@"Content-Type"];
        NSData *httpBody = [self createBodyWithBoundary:uuidStr path:fileURI parameters: parameters fieldName:fieldName];
        [request setHTTPBody: httpBody];
        operation = [[TRVSURLSessionOperation alloc] initWithSession:[self urlSession] uploadId:uploadId request:request];
    } else if ([uploadType isEqualToString:@"json"]) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSData *httpBody = [VydiaRNFileUploader normalizedJSONRequestBody:parameters];
        [request setHTTPBody:httpBody];
        operation = [[TRVSURLSessionOperation alloc] initWithSession:[self urlSession] uploadId:uploadId request:request];
    } else {
        if (parameters.count > 0) {
            RCTLogError(@"RN Uploader: Parameters supported only in 'multipart' and 'json' type");
            return [self removeUpload:uploadId];
        }
        operation = [[TRVSURLSessionOperation alloc] initWithSession:[self urlSession] uploadId:uploadId request:request fromFileUrl:[NSURL URLWithString:fileURI]];
    }
    [_operations setObject:operation forKey:uploadId];
    [queue addOperation:operation];
    NSLog(@"Request: %@ | %@", requestUrl.absoluteString, uploadId);
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
RCT_EXPORT_METHOD(startUpload:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *uploadId = [[[NSUUID UUID] UUIDString] lowercaseString];
    [defaults setObject:options forKey:uploadId];
    [_uploadIds addObject:uploadId];
    [defaults setObject:[_uploadIds array] forKey:@"backgroundUploads"];

    [self enqueueUpload:uploadId options:options];
    
    resolve(uploadId);
}

/*
 * Cancels file upload
 * Accepts upload ID as a first argument, this upload will be cancelled
 * Event "cancelled" will be fired when upload is cancelled.
 */
RCT_EXPORT_METHOD(cancelUpload: (NSString *)cancelUploadId resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [[self urlSession] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for (NSURLSessionTask *uploadTask in uploadTasks) {
            if (uploadTask.taskDescription == cancelUploadId) {
                [uploadTask cancel];
            }
        }
    }];
    resolve([NSNumber numberWithBool:YES]);
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                              path:(NSString *)path
                        parameters:(NSDictionary *)parameters
                         fieldName:(NSString *)fieldName {
    
    NSMutableData *httpBody = [NSMutableData data];
    
    NSData *data = [VydiaRNFileUploader dataForFile:path];
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

- (NSURLSession *)urlSession {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if (TARGET_IPHONE_SIMULATOR)
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
#else
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:BACKGROUND_SESSION_ID];
#endif
        config.allowsCellularAccess = YES;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.URLCache = nil;
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        config.timeoutIntervalForResource = 30.0;
        session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        session.sessionDescription = BACKGROUND_SESSION_ID;
    });
    return session;
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
    [self _sendEventWithName:@"RNFileUploader-progress" body:@{ @"id": task.taskDescription, @"progress": [NSNumber numberWithFloat:progress] }];
    NSLog(@"Progress: %@, %@", [NSNumber numberWithFloat:progress], task.taskDescription);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data.length) {
        return;
    }
    //Hold returned data so it can be picked up by the didCompleteWithError method later
    NSMutableData *responseData = _responsesData[@(dataTask.taskIdentifier)];
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
        _responsesData[@(dataTask.taskIdentifier)] = responseData;
    } else {
        [responseData appendData:data];
    }
    NSLog(@"DidReceiveData: %@", dataTask.taskDescription);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    
    NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithObjectsAndKeys:task.taskDescription, @"id", nil];
    NSURLSessionDataTask *uploadTask = (NSURLSessionDataTask *)task;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)uploadTask.response;
    NSString *uploadId = task.taskDescription;
    
    if (response) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
        [eventData setObject:[NSNumber numberWithInteger:httpResponse.statusCode] forKey:@"responseCode"];
    }
    
    //Add data that was collected earlier by the didReceiveData method
    NSMutableData *responseData = _responsesData[@(task.taskIdentifier)];
    if (responseData) {
        [_responsesData removeObjectForKey:@(task.taskIdentifier)];
        NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        [eventData setObject:response forKey:@"responseBody"];
        NSLog(@"Upload response for %@: %@", task.taskDescription, response);
    } else {
        [eventData setObject:[NSNull null] forKey:@"responseBody"];
    }
    
    NSLog(@"Completion handler %@: %@", uploadId, eventData);
    if (error == nil) {
        [self _sendEventWithName:@"RNFileUploader-completed" body:eventData];
    } else {
        NSLog(@"Upload error for %@: %@", uploadId, error.localizedDescription);
        [eventData setObject:error.localizedDescription forKey:@"error"];
        if (error.code == NSURLErrorCancelled) {
            [self _sendEventWithName:@"RNFileUploader-cancelled" body:eventData];
        } else {
            [self _sendEventWithName:@"RNFileUploader-error" body:eventData];
        }
    }
    
    [self removeUpload:uploadId];
    
}

@end






