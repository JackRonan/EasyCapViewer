/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "ECVAudioPipe.h"
#import <CoreAudio/CoreAudio.h>
#import <vecLib/vecLib.h>

// Other Sources
#import "ECVDebug.h"

@interface ECVAudioPipe(Private)

- (BOOL)_fillConversionBufferList:(AudioBufferList *)conversionBufferList;

@end

static OSStatus ECVAudioConverterComplexInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *conversionBufferList, AudioStreamPacketDescription **outDataPacketDescription, ECVAudioPipe *pipe)
{
	(void)[pipe _fillConversionBufferList:conversionBufferList];
	return noErr;
}

@implementation ECVAudioPipe

#pragma mark -ECVAudioPipe

- (id)initWithInputDescription:(AudioStreamBasicDescription)inputDesc outputDescription:(AudioStreamBasicDescription)outputDesc
{
	if((self = [super init])) {
		if(kAudioFormatLinearPCM != inputDesc.mFormatID) {
			[self release];
			return nil;
		}

		ECVOSStatus(AudioConverterNew(&inputDesc, &outputDesc, &_converter));
		if(!_converter) {
			[self release];
			return nil;
		}
		UInt32 quality = kAudioConverterQuality_Max;
		ECVOSStatus(AudioConverterSetProperty(_converter, kAudioConverterSampleRateConverterQuality, sizeof(quality), &quality));
		UInt32 primeMethod = kConverterPrimeMethod_Normal;
		ECVOSStatus(AudioConverterSetProperty(_converter, kAudioConverterPrimeMethod, sizeof(primeMethod), &primeMethod));

		_inputStreamDescription = inputDesc;
		_outputStreamDescription = outputDesc;
		_volume = 1.0f;
		_dropsBuffers = YES;
		_lock = [[NSLock alloc] init];
		_unusedBuffers = [[NSMutableArray alloc] init];
		_usedBuffers = [[NSMutableArray alloc] init];
	}
	return self;
}
@synthesize inputStreamDescription = _inputStreamDescription;
@synthesize outputStreamDescription = _outputStreamDescription;
@synthesize volume = _volume;
@synthesize dropsBuffers = _dropsBuffers;

#pragma mark -

- (void)receiveInputBufferList:(AudioBufferList const *)inputBufferList
{
	NSMutableArray *const buffers = [NSMutableArray arrayWithCapacity:inputBufferList->mNumberBuffers];
	NSUInteger i = 0;
	float const volume = pow(_volume, 2);
	for(; i < inputBufferList->mNumberBuffers; i++) {
		size_t const length = inputBufferList->mBuffers[i].mDataByteSize;
		if(!length) continue;
		void *const bytes = malloc(length);
		if(!bytes) continue;
		vDSP_vsmul(inputBufferList->mBuffers[i].mData, 1, &volume, bytes, 1, length / sizeof(float));
		[buffers addObject:[NSMutableData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES]];
	}
	[_lock lock];
	if(_dropsBuffers) [_unusedBuffers setArray:buffers];
	else [_unusedBuffers addObjectsFromArray:buffers];
	[_lock unlock];
}
- (void)requestOutputBufferList:(inout AudioBufferList *)outputBufferList
{
	if(!outputBufferList || !outputBufferList->mNumberBuffers) return;
	NSUInteger i = 0;
	UInt32 packetCount = 0;
	for(; i < outputBufferList->mNumberBuffers; i++) packetCount += outputBufferList->mBuffers[i].mDataByteSize / _outputStreamDescription.mBytesPerPacket;
	(void)AudioConverterFillComplexBuffer(_converter, (AudioConverterComplexInputDataProc)ECVAudioConverterComplexInputDataProc, self, &packetCount, outputBufferList, NULL);
	[_usedBuffers removeAllObjects];
}

#pragma mark -ECVAudioPipe(Private)

- (BOOL)_fillConversionBufferList:(AudioBufferList *)conversionBufferList
{
	[_lock lock];
	NSUInteger const srcCount = [_unusedBuffers count];
	UInt32 const dstCount = conversionBufferList->mNumberBuffers;
	UInt32 const minCount = MIN(srcCount, dstCount);

	NSRange const bufferRange = NSMakeRange(0, minCount);
	NSArray *const buffers = [_unusedBuffers subarrayWithRange:bufferRange];
	[_usedBuffers addObjectsFromArray:buffers];
	[_unusedBuffers removeObjectsInRange:bufferRange];
	[_lock unlock];

	NSUInteger i = 0;
	for(; i < minCount; i++) {
		NSMutableData *const data = [buffers objectAtIndex:i];
		conversionBufferList->mBuffers[i].mDataByteSize = [data length];
		conversionBufferList->mBuffers[i].mData = [data mutableBytes];
	}
	if(i >= dstCount) return YES;
	for(; i < dstCount; i++) {
		conversionBufferList->mBuffers[i].mDataByteSize = 0;
		conversionBufferList->mBuffers[i].mData = NULL;
	}
	return NO;
}

#pragma mark -NSObject

- (void)dealloc
{
	ECVOSStatus(AudioConverterDispose(_converter));
	[_lock release];
	[_unusedBuffers release];
	[_usedBuffers release];
	[super dealloc];
}

@end
