[![Build Status](https://travis-ci.org/dstnbrkr/VCRURLConnection.png?branch=master)](https://travis-ci.org/dstnbrkr/VCRURLConnection)

TODO: Update this

# iOS-VCR
Originally forked from [VCRURLConnection](https://github.com/dstnbrkr/VCRURLConnection), this package provides VCR functionality for AFNetworking on iOS.


## Recording 

``` objective-c
[VCR start];
 
NSString *path = @"http://example.com/example";
NSURL *url = [NSURL URLWithString:path];
NSURLRequest *request = [NSURLRequest requestWithURL:url];

// use either NSURLSession or NSURLConnection
NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request];
[task resume];
 
// NSURLSession makes a real network request and VCRURLConnection
// will record the request/response pair.

// once async request is complete or application is ready to exit:
[VCR save:@"/path/to/cassette.json"]; // copy the output file into your project
```

## Replaying

``` objective-c
NSURL *cassetteURL = [NSURL fileURLWithPath:@"/path/to/cassette.json"];
[VCR loadCassetteWithContentsOfURL:cassetteURL];
[VCR start];

// request an HTTP interaction that was recorded to cassette.json
NSString *path = @"http://example.com/example";
NSURL *url = [NSURL URLWithString:path];
NSURLRequest *request = [NSURLRequest requestWithURL:url];

// use either NSURLSession or NSURLConnection
NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request];
[task resume];
 
// The cassette has a recording for this request, so no network request
// is made. Instead NSURLConnectionDelegate methods are called with the
// previously recorded response.
```

## How to get started
- [Download VCRURLConnection](https://github.com/dstnbrkr/VCRURLConnection/zipball/master) and try out the included example app
- Include the files in the VCRURLConnection folder in your test target
- Run your tests once to record all HTTP interactions
- Copy the recorded json file (the file whose path is returned by `[VCR save]`) into your project
- Subsequent test runs will use the recorded HTTP interactions instead of the network

- All recordings are stored in a single JSON file, which you can edit by hand

## License

VCRURLConnection is released under the MIT license

## Contact

Dustin Barker

dustin.barker@gmail.com

### VCRURLConnection uses the following open source components:

* [SenTestCase+SRTAdditions.h][1] from SocketRocket by Square

[1]: https://github.com/square/SocketRocket
