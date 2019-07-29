//
//  AACPlayer.m
//  ACCDecode
//
//  Created by Myron on 2019/6/10.
//  Copyright © 2019 Myron. All rights reserved.
//

#import "AACPlayer.h"

const uint32_t CONST_BUFFER_COUNT = 3;
const uint32_t CONST_BUFFER_SIZE = 0x10000;

@implementation AACPlayer

{
    //播放音频文件ID
    AudioFileID audioFileID; // An opaque data type that represents an audio file object.
    //音频流描述对象
    AudioStreamBasicDescription audioStreamBasicDescrpition; // An audio data format specification for a stream of audio
    AudioStreamPacketDescription *audioStreamPacketDescrption; // Describes one packet in a buffer of audio data where the sizes of the packets differ or where there is non-audio data between audio packets.
    //音频队列
    AudioQueueRef audioQueue; // Defines an opaque data type that represents an audio queue.
    AudioQueueBufferRef audioBuffers[CONST_BUFFER_COUNT];
    
    SInt64 readedPacket; //参数类型
    u_int32_t packetNums;
    
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [self customAudioConfig];
    }
    return self;
}

- (void)customAudioConfig {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"AACFile" withExtension:@"aac"];
    //打开音频文件
    /**
     AudioFileOpenURL (
     CFURLRef inFileRef, // 打开文件的路径
     SInt8 inPermissions, // 打开文件的权限。 读／写／读写三种权限
     AudioFileTypeID inFileTypeHint, // 文件类型提示信息，如果明确知道就填入，如果不知道填0.
     AudioFileID * outAudioFile // 文件述符 ID
     );
     */
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID); //Open an existing audio file specified by a URL.
    if (status != noErr) {
        NSLog(@"打开文件失败 %@", url);
        return ;
    }
    uint32_t size = sizeof(audioStreamBasicDescrpition);
    //取得音频数据格式
    /**
     udioFileGetProperty(
     AudioFileID inAudioFile, //文件描述符，通过 AudioFileOpenURL 获取。
     AudioFilePropertyID inPropertyID, //属性ID，如上所示
     UInt32 * ioDataSize, // 输出值空间大小
     void * outPropertyData //输出值地址。
     );
     */
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioStreamBasicDescrpition); // Gets the value of an audio file property.
    NSAssert(status == noErr, @"error");
    //创建播放用的音频队列
    status = AudioQueueNewOutput(&audioStreamBasicDescrpition, bufferReady, (__bridge void * _Nullable)(self), NULL, NULL, 0, &audioQueue); // Creates a new playback audio queue object.
    NSAssert(status == noErr, @"error");
    //计算单位时间包含的包数
    if (audioStreamBasicDescrpition.mBytesPerPacket == 0 || audioStreamBasicDescrpition.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        AudioFileGetProperty(audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize); // The theoretical maximum packet size in the file.
        if (maxSize > CONST_BUFFER_SIZE) {
            maxSize = CONST_BUFFER_SIZE;
        }
        //算出单位时间内含有的包数
        packetNums = CONST_BUFFER_SIZE / maxSize;
        audioStreamPacketDescrption = malloc(sizeof(AudioStreamPacketDescription) * packetNums);
    }
    else {
        packetNums = CONST_BUFFER_SIZE / audioStreamBasicDescrpition.mBytesPerPacket;
        audioStreamPacketDescrption = nil;
    }
    
    char cookies[100];
    memset(cookies, 0, sizeof(cookies));
    //设置Magic Cookie
    //AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, nil);
    //if (size >0) {
    //    cookie=malloc(sizeof(char)*size);
    //    AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
    //    AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, cookie, size);
    //}
    //设置Magic Cookie 这里的100 有问题
    AudioFileGetProperty(audioFileID, kAudioFilePropertyMagicCookieData, &size, cookies); // Some file types require that a magic cookie be provided before packets can be written to an audio file.
    if (size > 0) {
        AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookies, size); // Sets an audio queue property value.
    }
    //创建并分配缓冲空间
    readedPacket = 0;
    for (int i = 0; i < CONST_BUFFER_COUNT; ++i) {
        AudioQueueAllocateBuffer(audioQueue, CONST_BUFFER_SIZE, &audioBuffers[i]); // Asks an audio queue object to allocate an audio queue buffer.
        //读取包数据
        if ([self fillBuffer:audioBuffers[i]]) {
            // full
            break;
        }
        NSLog(@"buffer%d full", i);
    }
}

void bufferReady(void *inUserData,AudioQueueRef inAQ,
                 AudioQueueBufferRef buffer){
    NSLog(@"refresh buffer");
    AACPlayer* player = (__bridge AACPlayer *)inUserData;
    if (!player) {
        NSLog(@"player nil");
        return ;
    }
    if ([player fillBuffer:buffer]) {
        NSLog(@"play end");
    }
    
}


- (void)play {
    //设置音量
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0); // Sets a playback audio queue parameter value.
    //队列处理开始，此后系统开始自动调用回调(Callback)函数
    AudioQueueStart(audioQueue, NULL); // Begins playing or recording audio.
}


- (bool)fillBuffer:(AudioQueueBufferRef)buffer {
    bool full = NO;
    uint32_t bytes = 0, packets = (uint32_t)packetNums;
    //从文件中接受数据并保存到缓存(buffer)中
    /**
     AudioFileReadPacketData (
        AudioFileID inAudioFile, // 文件描述符
        Boolean inUseCache,       // 是否使用cache, 一般不用
        UInt32 * ioNumBytes,      // 输入输出参数
        AudioStreamPacketDescription * outPacketDescriptions, //输出参数
        SInt64 inStartingPacket, // 要读取的第一个数据包的数据包索引。
        UInt32 * ioNumPackets,  // 输入输出参数
        void * outBuffer //输出内存地址
     );

     */
    OSStatus status = AudioFileReadPackets(audioFileID, NO, &bytes, audioStreamPacketDescrption, readedPacket, &packets, buffer->mAudioData); // Reads packets of audio data from an audio file.
//    OSStatus status = AudioFileReadPacketData(audioFileID, NO, &bytes, audioStreamPacketDescrption, readedPacket, &packets, buffer->mAudioData);
    
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    if (packets > 0) {
        buffer->mAudioDataByteSize = bytes;
        AudioQueueEnqueueBuffer(audioQueue, buffer, packets, audioStreamPacketDescrption);
        readedPacket += packets;
    }
    else {
        AudioQueueStop(audioQueue, NO);
        full = YES;
    }
    
    return full;
}



- (double)getCurrentTime {
    Float64 timeInterval = 0.0;
    if (audioQueue) {
        AudioQueueTimelineRef timeLine;
        AudioTimeStamp timeStamp;
        OSStatus status = AudioQueueCreateTimeline(audioQueue, &timeLine); // Creates a timeline object for an audio queue.
        if(status == noErr)
        {
            AudioQueueGetCurrentTime(audioQueue, timeLine, &timeStamp, NULL); // Gets the current audio queue time.
            timeInterval = timeStamp.mSampleTime * 1000000 / audioStreamBasicDescrpition.mSampleRate; // The number of sample frames per second of the data in the stream.
        }
    }
    return timeInterval;
}


@end
