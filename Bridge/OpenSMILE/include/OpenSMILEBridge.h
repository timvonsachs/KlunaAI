// OpenSMILEBridge.h

#import <Foundation/Foundation.h>

@interface OpenSMILEBridge : NSObject

- (instancetype)initWithConfig:(NSString *)configPath;

/// Extract features from PCM audio data (full session or segment).
- (NSDictionary<NSString *, NSNumber *> *)extractFeaturesFromPCMData:(NSData *)pcmData
                                                          sampleRate:(double)sampleRate;

/// Extract features from a time segment within audio data.
- (NSDictionary<NSString *, NSNumber *> *)extractFeaturesFromPCMData:(NSData *)pcmData
                                                          sampleRate:(double)sampleRate
                                                           startTime:(double)startTime
                                                             endTime:(double)endTime;

@end
