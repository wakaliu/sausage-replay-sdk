//
//  SRErrorCodes.m
//  SausageReplay
//

#import "SRErrorCodes.h"

@implementation SRErrorCodes

+ (NSString *)messageFor:(SRErrorCode)code {
    switch (code) {
        case SRErrorOK: return @"OK";
        case SRErrorRecordingAlreadyInProgress: return @"Recording already in progress";
        case SRErrorRecordingNotStarted: return @"Recording not started";
        case SRErrorUserDenied: return @"User denied screen capture permission";
        case SRErrorCreateProjectionFailed: return @"Failed to create capture session";
        case SRErrorStartFailed: return @"Start recording failed";
        case SRErrorStartTimeout: return @"Recording start timeout";
        case SRErrorWriterNotStarted: return @"Writer not started or no frames captured";
        case SRErrorPhotoPermissionDenied: return @"Photo permission denied";
        case SRErrorSaveToPhotosFailed: return @"Save to Photos failed";
        case SRErrorDurationTooShort: return @"Recording too short (<1s)";
        case SRErrorFormatNotSupported: return @"Format not supported";
    }
}

@end


