//
//  main.m
//  SausageReplayDemo
//
//  Created by Waka on 2025/10/10.
//

#import <UIKit/UIKit.h>
#import <stdlib.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        // Workaround for simulator malloc issue: xzm: failed to initialize deferred reclamation buffer
        setenv("MallocNanoZone", "0", 1);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}


