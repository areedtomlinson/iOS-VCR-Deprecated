//
// VCRRecording.m
//
// Copyright (c) 2012 Dustin Barker
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

#import "VCRRecording.h"
#import "VCROrderedMutableDictionary.h"
#import "VCRError.h"
#import <MobileCoreServices/MobileCoreServices.h>

// For -[NSData initWithBase64Encoding:] and -[NSData base64Encoding]
// Remove when targetting iOS 7+, use -[NSData initWithBase64EncodedString:options:] and -[NSData base64EncodedStringWithOptions:] instead
#pragma clang diagnostic ignored "-Wdeprecated"

@implementation VCRRecording

- (id)initWithJSON:(id)json {
    if ((self = [self init])) {
        NSMutableDictionary *requestJSON = json[@"request"];
        NSMutableDictionary *responseJSON = json[@"response"];
        
        self.method = requestJSON[@"method"];
        NSAssert(self.method, @"VCRRecording: method is required");
        
        self.URI = requestJSON[@"url"];
        NSAssert(self.URI, @"VCRRecording: url is required");

        self.statusCode = [responseJSON[@"code"] intValue];

        self.requestHeaderFields = requestJSON[@"@headers"];
        if (!self.requestHeaderFields) {
            self.requestHeaderFields = [NSDictionary dictionary];
        }
        
        self.responseHeaderFields = responseJSON[@"headers"];
        if (!self.responseHeaderFields) {
            self.responseHeaderFields = [NSDictionary dictionary];
        }
        
        NSString *requestBody = requestJSON[@"body"];
        [self setRequestBody:requestBody];
        
        NSString *responseBody = responseJSON[@"body"];
        [self setResponseBody:responseBody];
        
        if (json[@"error"]) {
            self.error = [[VCRError alloc] initWithJSON:json[@"error"]];
        }
    }
    return self;
}

- (BOOL)isEqual:(VCRRecording *)recording {
    return [self.method isEqualToString:recording.method] &&
           [self.URI isEqualToString:recording.URI] &&
           [self.requestBody isEqualToString:recording.requestBody];
}

- (NSUInteger)hash {
    const NSUInteger prime = 17;
    NSUInteger hash = 1;
    hash = prime * hash + [self.method hash];
    hash = prime * hash + [self.URI hash];
    hash = prime * hash + [self.responseBody hash];
    return hash;
}

- (BOOL)isText {
    NSString *type = [[self HTTPURLResponse] MIMEType] ?: @"text/plain";
    if ([@[ @"application/x-www-form-urlencoded" ] containsObject:type]) {
        return YES;
    }
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)type, NULL);
    BOOL isText = UTTypeConformsTo(uti, kUTTypeText);
    if (uti) {
        CFRelease(uti);
    }
    return isText;
}

- (void)setRequestBody:(id)body
{
    if ([body isKindOfClass:[NSDictionary class]]) {
        self.requestData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else if ([self isText]) {
        self.requestData = [body dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([body isKindOfClass:[NSString class]]) {
        self.requestData = [[NSData alloc] initWithBase64Encoding:body];
    }
}

- (void)setResponseBody:(id)body
{
    if ([body isKindOfClass:[NSDictionary class]]) {
        self.responseData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else if ([self isText]) {
        self.responseData = [body dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([body isKindOfClass:[NSString class]]) {
        self.responseData = [[NSData alloc] initWithBase64Encoding:body];
    }
}

- (NSString *)requestBody {
    if ([self isText]) {
        return [[NSString alloc] initWithData:self.requestData encoding:NSUTF8StringEncoding];
    } else {
        return [self.requestData base64Encoding];
    }
}

- (NSString *)responseBody {
    if ([self isText]) {
        return [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    } else {
        return [self.responseData base64Encoding];
    }
}

- (id)requestJSON {
    NSDictionary *infoDict = @{
                               @"url": self.URI,
                               @"method": self.method,
                               @"headers": self.requestHeaderFields,
                               @"body": self.requestBody
                               };
    VCROrderedMutableDictionary *dictionary = [VCROrderedMutableDictionary dictionaryWithDictionary:infoDict];
    return dictionary;
}

- (id)responseJSON {
    NSDictionary *infoDict = @{
                               @"headers": self.responseHeaderFields,
                               @"url": self.URI,
                               @"code": @(self.statusCode),
                               @"body": self.responseBody
                               };
    VCROrderedMutableDictionary *dictionary = [VCROrderedMutableDictionary dictionaryWithDictionary:infoDict];
    return dictionary;
}

- (id)JSON {
    NSDictionary *infoDict = @{
                               @"request": self.requestJSON,
                               @"response": self.responseJSON
                               };
    VCROrderedMutableDictionary *dictionary = [VCROrderedMutableDictionary dictionaryWithDictionary:infoDict];
    
    NSError *error = self.error;
    if (error) {
        @try {
            dictionary[@"error"] = [VCRError JSONForError:error];
        }
        @catch(NSException *exception) {
            // Error encoding JSON. Put in placeholder value.
            dictionary[@"error"] = @"";
        }
    }
    
    VCROrderedMutableDictionary *sortedDict = [VCROrderedMutableDictionary dictionaryWithCapacity:[infoDict count]];
    [[dictionary sortedKeys] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        sortedDict[key] = dictionary[key];
    }];
    
    return sortedDict;
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<VCRRecording %@ %@, data length %li>", self.method, self.URI, (unsigned long)[self.responseData length]];
}

- (NSHTTPURLResponse *)HTTPURLResponse {
    NSURL *url = [NSURL URLWithString:_URI];
    return [[NSHTTPURLResponse alloc] initWithURL:url
                                       statusCode:_statusCode
                                      HTTPVersion:@"HTTP/1.1"
                                     headerFields:_responseHeaderFields];
}

@end

