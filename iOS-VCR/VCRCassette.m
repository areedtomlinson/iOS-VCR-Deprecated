//
// VCRCassette.m
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

#import "VCRCassette.h"
#import "VCRCassette_Private.h"
#import "VCRRequestKey.h"


@implementation VCRCassette

+ (VCRCassette *)cassette {
    return [[VCRCassette alloc] init];
}

+ (VCRCassette *)cassetteWithURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    return [[VCRCassette alloc] initWithData:data];
}

- (id)init {
    if ((self = [super init])) {
        self.responseDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithJSON:(id)json {
    NSAssert(json != nil, @"Attempted to intialize VCRCassette with nil JSON");
    if ((self = [self init])) {
        for (id urlKey in json) {
            NSMutableDictionary *jsonForURL = json[urlKey];
            for (id methodKey in jsonForURL) {
                NSMutableArray *transactions = jsonForURL[methodKey];
                for(id transactionJSON in transactions) {
                    VCRRecording *recording = [[VCRRecording alloc] initWithJSON:transactionJSON];
                    [self addRecording:recording];
                }
            }
        }
    }
    return self;
}

- (id)initWithData:(NSData *)data {
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSAssert([error code] == 0, @"Attempted to initialize VCRCassette with invalid JSON");
    return [self initWithJSON:json];
    
}

- (void)addRecording:(VCRRecording *)recording {
    VCRRequestKey *key = [VCRRequestKey keyForObject:recording];
    // Add recording to an array
    NSMutableArray *transactions = [self getAllTransactionsForKey:key];
    [transactions addObject:recording];
    [self.responseDictionary setObject:transactions forKey:key];
}

- (bool)compareURL:(NSString *)url1 toURL:(NSString *)url2 {
    // Remove base URLs from both:
    NSMutableArray *components = [[url1 componentsSeparatedByString:@"/"] mutableCopy];
    [components removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)]];
    url1 = [components componentsJoinedByString:@"/"];
    
    NSMutableArray *components2 = [[url2 componentsSeparatedByString:@"/"] mutableCopy];
    [components2 removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)]];
    url2 = [components2 componentsJoinedByString:@"/"];
    
    return [url1 isEqualToString:url2];
}

- (VCRRequestKey *)keyMatchingRequestKey:(VCRRequestKey *)key {
    //
    // Find a VCRRequestKey that "matches" this one (according to our comparator function)
    //
    NSMutableArray *keys = [[self.responseDictionary allKeys] mutableCopy];
    for(int i=0; i<keys.count; i++) {
        VCRRequestKey *thisKey = keys[i];
        if([thisKey.method isEqualToString:key.method] && [self compareURL:thisKey.URI toURL:key.URI]) {
            return thisKey;
        }
    }
    return nil;
}

- (NSMutableArray *)getAllTransactionsForKey:(VCRRequestKey *)key {
    //
    // Return the array of ordered transactions for this key.
    //
    VCRRequestKey *matchingKey = [self keyMatchingRequestKey:key];
    if(matchingKey) {
        NSMutableArray *transactionArray = [[self.responseDictionary objectForKey:matchingKey] mutableCopy];
        return transactionArray;
    }
    return [[NSMutableArray alloc] init];
}

- (void)setTransactionsForKey:(VCRRequestKey *)key transactions:(NSMutableArray *)transactions {
    //
    // Replace the array of ordered transactions for this key.
    //
    VCRRequestKey *matchingKey = [self keyMatchingRequestKey:key];
    if(matchingKey) {
        [self.responseDictionary setObject:transactions forKey:matchingKey];
    }
}

- (VCRRecording *)getTransactionForKey:(VCRRequestKey *)key {
    //
    // Get the next ordered transaction for this key.
    //
    printf("getTransactionForKey %s\n", [key.URI cStringUsingEncoding:NSUTF8StringEncoding]);
    NSMutableArray *transactionsForKey = [self getAllTransactionsForKey:key];
    VCRRecording *recording = nil;
    if([transactionsForKey count] > 0) {
        recording = [transactionsForKey objectAtIndex:0];
    }
    return recording;
}

- (VCRRecording *)popTransactionForKey:(VCRRequestKey *)key {
    //
    // Get the next ordered transaction for this key and remove it from the list.
    //
    printf("popTransactionForKey %s\n", [key.URI cStringUsingEncoding:NSUTF8StringEncoding]);
    NSMutableArray *transactionsForKey = [self getAllTransactionsForKey:key];
    VCRRecording *recording = nil;
    if([transactionsForKey count] > 0) {
        recording = [transactionsForKey objectAtIndex:0];
        [transactionsForKey removeObjectAtIndex:0];
        // Push that change back:
        [self setTransactionsForKey:key transactions:transactionsForKey];
    }
    return recording;
}

- (VCRRecording *)recordingForRequestKey:(VCRRequestKey *)key {
    return [self getTransactionForKey:key];
}

- (VCRRecording *)recordingForRequest:(NSURLRequest *)request {
    VCRRequestKey *key = [VCRRequestKey keyForObject:request];
    return [self recordingForRequestKey:key];
}

- (id)JSON {
    NSMutableDictionary *recordings = [[NSMutableDictionary alloc] init];
    for(VCRRequestKey *key in self.responseDictionary.allKeys) {
        // Try to find a matching URL in the JSON:
        NSMutableDictionary *transactionsForURL = [recordings valueForKey:key.URI];
        if(transactionsForURL==nil) {
            transactionsForURL = [[NSMutableDictionary alloc] init];
        }
        
        // Try to find method key in recordings:
        NSMutableArray *transactionsForMethod = [transactionsForURL valueForKey:key.method];
        if(transactionsForMethod==nil) {
            transactionsForMethod = [[NSMutableArray alloc] init];
        }
        
        //NSMutableArray *recordingArray = [self.responseDictionary valueForKey:key];
        NSMutableArray *recordingArray = [self getAllTransactionsForKey:key];
        for(VCRRecording *recording in recordingArray) {
            [transactionsForMethod addObject:[recording JSON]];
        }
        
        [transactionsForURL setObject:transactionsForMethod forKey:key.method];
        [recordings setObject:transactionsForURL forKey:key.URI];
    }

    return recordings;
}

- (NSData *)data {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self JSON]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if ([error code] != 0) {
        NSLog(@"Error serializing json data %@", error);
    }
    return data;
}

- (BOOL)isEqual:(VCRCassette *)cassette {
    return [self.responseDictionary isEqual:cassette.responseDictionary];
}

- (NSUInteger)hash {
    return [self.responseDictionary hash];
}

- (NSArray *)allKeys {
    return [self.responseDictionary allKeys];
}

@end
