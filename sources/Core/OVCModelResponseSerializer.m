// OVCModelResponseSerializer.m
//
// Copyright (c) 2013 Guillermo Gonzalez
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "OVCModelResponseSerializer.h"
#import <Mantle/Mantle.h>
#import "OVCUtilities.h"
#import "OVCResponse.h"
#import "OVCURLMatcher.h"
#import "NSError+OVCResponse.h"

@interface OVCModelResponseSerializer ()

@property (strong, nonatomic) OVCURLMatcher *URLMatcher;
@property (strong, nonatomic) OVCURLMatcher *URLResponseClassMatcher;
@property (nonatomic) Class responseClass;
@property (nonatomic) Class errorModelClass;

@end

@implementation OVCModelResponseSerializer

+ (instancetype)serializerWithURLMatcher:(OVCURLMatcher *)URLMatcher
                 responseClassURLMatcher:(OVCURLMatcher *)URLResponseClassMatcher
                           responseClass:(Class)responseClass
                         errorModelClass:(Class)errorModelClass {
    return [[self alloc] initWithURLMatcher:URLMatcher
                    responseClassURLMatcher:URLResponseClassMatcher
                              responseClass:responseClass
                            errorModelClass:errorModelClass];
}

- (instancetype)init {
    return [self initWithURLMatcher:[[OVCURLMatcher alloc] initWithBasePath:nil modelClassesByPath:nil]
            responseClassURLMatcher:nil
                      responseClass:[OVCResponse class]
                    errorModelClass:nil];
}

- (instancetype)initWithURLMatcher:(OVCURLMatcher *)URLMatcher
           responseClassURLMatcher:(OVCURLMatcher *)URLResponseClassMatcher
                     responseClass:(Class)responseClass
                   errorModelClass:(Class)errorModelClass {
    NSParameterAssert([responseClass isSubclassOfClass:[OVCResponse class]]);

    if (errorModelClass != Nil) {
        NSParameterAssert([errorModelClass conformsToProtocol:@protocol(MTLModel)]);
    }

    if (self = [super init]) {
        self.jsonSerializer = [AFJSONResponseSerializer serializerWithReadingOptions:0];

        self.URLMatcher = URLMatcher;
        self.URLResponseClassMatcher = URLResponseClassMatcher;
        self.responseClass = responseClass;
        self.errorModelClass = errorModelClass;
    }
    return self;
}

#pragma mark - AFURLRequestSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error {
    NSError *serializationError = nil;
    id OVC__NULLABLE JSONObject = [self.jsonSerializer responseObjectForResponse:response
                                                                            data:data
                                                                           error:&serializationError];

    if (error) {
        *error = serializationError;
    }

    if (serializationError && serializationError.code != NSURLErrorBadServerResponse) {
        return nil;
    }

    NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
    Class resultClass = Nil;
    Class responseClass = Nil;

    if (!serializationError) {
        resultClass = [self.URLMatcher modelClassForURL:HTTPResponse.URL];

        if (self.URLResponseClassMatcher) {
            responseClass = [self.URLResponseClassMatcher modelClassForURL:HTTPResponse.URL];
        }

        if (!responseClass) {
            responseClass = self.responseClass;
        }
    } else {
        resultClass = self.errorModelClass;
        responseClass = self.responseClass;
    }

    OVCResponse *responseObject = [responseClass responseWithHTTPResponse:HTTPResponse
                                                               JSONObject:JSONObject
                                                              resultClass:resultClass
                                                                    error:&serializationError];
    if (serializationError && error) {
        *error = serializationError;
    }

    return responseObject;
}

- (NSSet *)acceptableContentTypes {
    return self.jsonSerializer.acceptableContentTypes;
}

- (NSIndexSet *)acceptableStatusCodes {
    return self.jsonSerializer.acceptableStatusCodes;
}

- (NSStringEncoding)stringEncoding {
    return self.jsonSerializer.stringEncoding;
}

@end
