//
//  SRLogger.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRLogger.h"

@implementation SRLogger

static BOOL _enabled = YES;

+ (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
}

+ (void)debug:(NSString *)tag message:(NSString *)message {
    if (!_enabled) return;
    NSLog(@"[SRecordSDK][DEBUG][%@] %@", tag, message);
}

+ (void)info:(NSString *)tag message:(NSString *)message {
    if (!_enabled) return;
    NSLog(@"[SRecordSDK][INFO][%@] %@", tag, message);
}

+ (void)warn:(NSString *)tag message:(NSString *)message {
    if (!_enabled) return;
    NSLog(@"[SRecordSDK][WARN][%@] %@", tag, message);
}

+ (void)error:(NSString *)tag message:(NSString *)message {
    if (!_enabled) return;
    NSLog(@"[SRecordSDK][ERROR][%@] %@", tag, message);
}

+ (void)error:(NSString *)tag message:(NSString *)message error:(nullable NSError *)error {
    if (!_enabled) return;
    if (error) {
        NSLog(@"[SRecordSDK][ERROR][%@] %@: %@", tag, message, error.localizedDescription);
    } else {
        NSLog(@"[SRecordSDK][ERROR][%@] %@", tag, message);
    }
}

@end

