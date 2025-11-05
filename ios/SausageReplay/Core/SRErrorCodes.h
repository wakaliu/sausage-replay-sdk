//
//  SRErrorCodes.h
//  SausageReplay
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SRErrorCode) {
    SRErrorOK = 0,
    SRErrorRecordingAlreadyInProgress = 2000,
    SRErrorRecordingNotStarted = 2001,
    SRErrorUserDenied = 2002,
    SRErrorCreateProjectionFailed = 2003,
    SRErrorStartFailed = 2004,
    SRErrorStartTimeout = 2005,
    SRErrorWriterNotStarted = 2006,
    SRErrorPhotoPermissionDenied = 1202,
    SRErrorSaveToPhotosFailed = 1203,
    SRErrorDurationTooShort = 2011,
    SRErrorFormatNotSupported = 3004
};

@interface SRErrorCodes : NSObject

+ (NSString *)messageFor:(SRErrorCode)code;

@end


