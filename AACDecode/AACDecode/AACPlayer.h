//
//  AACPlayer.h
//  ACCDecode
//
//  Created by Myron on 2019/6/10.
//  Copyright © 2019 Myron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AACPlayer : NSObject

- (void)play;

- (double)getCurrentTime;

@end

NS_ASSUME_NONNULL_END
