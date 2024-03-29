//
//  ViewController.m
//  ACCDecode
//
//  Created by Myron on 2019/6/10.
//  Copyright © 2019 Myron. All rights reserved.
//

#import "ViewController.h"
#import "AACPlayer.h"

@interface ViewController ()

@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) UILabel *mCurrentTimeLabel;
@property (nonatomic , strong) UIButton *mButton;
@property (nonatomic , strong) UIButton *mDecodeButton;
@property (nonatomic , strong) CADisplayLink *mDispalyLink;

@end

@implementation ViewController
{
    AACPlayer *player;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 100)];
    self.mLabel.textColor = [UIColor blackColor];
    [self.view addSubview:self.mLabel];
    self.mLabel.text = @"测试ACC播放";
    
    self.mCurrentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 100)];
    self.mCurrentTimeLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mCurrentTimeLabel];
    
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(200, 20, 100, 100)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    self.mButton = button;
    
    self.mDecodeButton = [[UIButton alloc] initWithFrame:CGRectMake(150, 20, 100, 100)];
    [self.mDecodeButton setTitle:@"decode" forState:UIControlStateNormal];
    [self.mDecodeButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:self.mDecodeButton];
    [self.mDecodeButton addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];
    
    
    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
//    self.mDispalyLink.frameInterval = 5;
    self.mDispalyLink.preferredFramesPerSecond = 30;
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.mDispalyLink setPaused:YES];
}

- (void)onClick:(UIButton *)button {
    [self.mButton setHidden:YES];
    NSURL *audioURL=[[NSBundle mainBundle] URLForResource:@"AACFile" withExtension:@"aac"];
    SystemSoundID soundID;
    //Creates a system sound object.
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(audioURL), &soundID);
    //Registers a callback function that is invoked when a specified system sound finishes playing.
    AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, &playCallback, (__bridge void * _Nullable)(self));
    //    AudioServicesPlayAlertSound(soundID);
    AudioServicesPlaySystemSound(soundID);
}

- (void)onPlayCallback {
    [self.mButton setHidden:NO];
}

void playCallback(SystemSoundID ID, void  * clientData){
    ViewController* controller = (__bridge ViewController *)clientData;
    [controller onPlayCallback];
}

- (void)onDecodeStart {
    self.mDecodeButton.hidden = YES;
    player = [[AACPlayer alloc] init];
    [player play];
    [self.mDispalyLink setPaused:NO];
}

- (void)updateFrame {
    if (player) {
        self.mCurrentTimeLabel.text = [NSString stringWithFormat:@"当前时间:%.1fs", [player getCurrentTime]];
    }
}


@end
