
#include "cinder/app/App.h"
#include "cinder/Url.h"

#if defined( CINDER_COCOA )
    #import <AVFoundation/AVFoundation.h>
    #if defined( CINDER_COCOA_TOUCH )
        #import <CoreVideo/CoreVideo.h>
    #else
        #import <CoreVideo/CVDisplayLink.h>
    #endif
#endif

#include "Avf.h"
#include "AvfUtils.h"

////////////////////////////////////////////////////////////////////////
//
// TODO: use global time from the system clock
// TODO: setup CADisplayLink for iOS, remove CVDisplayLink callback on OSX
// TODO: test operations for thread-safety -- add/remove locks as necessary
//
////////////////////////////////////////////////////////////////////////

static void* AVPlayerItemStatusContext = &AVPlayerItemStatusContext;

@interface MovieDelegate : NSObject<AVPlayerItemOutputPullDelegate> {
	ci::avf::MovieResponder* responder;
#if defined( CINDER_COCOA_TOUCH )
    CADisplayLink* displayLink;
#endif
}

- (id)initWithResponder:(ci::avf::MovieResponder*)player;
#if defined( CINDER_COCOA_TOUCH )
- (void)initDisplayLink;
#endif
- (void)playerReady;
- (void)playerItemDidReachEndCallback;
- (void)playerItemDidNotReachEndCallback;
- (void)playerItemTimeJumpedCallback;
#if defined( CINDER_COCOA_TOUCH )
- (void)displayLinkCallback:(CADisplayLink*)sender;
#elif defined( CINDER_COCOA )
- (void)displayLinkCallback:(CVDisplayLinkRef*)sender;
#endif
- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output;

@end


@implementation MovieDelegate

- (void)dealloc
{
#if defined( CINDER_COCOA_TOUCH )
    [self->displayLink release];
#endif
	[super dealloc];
}

- (id)init
{
	self = [super init];
	self->responder = nil;

#if defined( CINDER_COCOA_TOUCH )
    [self initDisplayLink];
#endif
    return self;
}

- (id)initWithResponder:(ci::avf::MovieResponder*)player
{
	self = [super init];
	self->responder = player;

#if defined( CINDER_COCOA_TOUCH )
    [self initDisplayLink];
#endif
	return self;
}

#if defined( CINDER_COCOA_TOUCH )
- (void)initDisplayLink
{
    [self->displayLink invalidate];
    self->displayLink = nil;
    
    self->displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)] ;
    [self->displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}
#endif

- (void)playerReady
{
	self->responder->playerReadyCallback();
}

- (void)playerItemDidReachEndCallback
{
	self->responder->playerItemDidReachEndCallback();
}

- (void)playerItemDidNotReachEndCallback
{
	self->responder->playerItemDidNotReachEndCallback();
}

- (void)playerItemTimeJumpedCallback
{
	self->responder->playerItemTimeJumpedCallback();
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
	if (context == AVPlayerItemStatusContext) {
		AVPlayerItem* player_item = (AVPlayerItem*)object;
		AVPlayerItemStatus status = [player_item status];
		switch (status) {
			case AVPlayerItemStatusUnknown:
				//ci::app::console() << "AVPlayerItemStatusUnknown" << std::endl;
				break;
			case AVPlayerItemStatusReadyToPlay:
				[self playerReady];
				break;
			case AVPlayerItemStatusFailed:
				//ci::app::console() << "AVPlayerItemStatusFailed" << std::endl;
				break;
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark - CADisplayLink Callback

#if defined( CINDER_COCOA_TOUCH )
- (void)displayLinkCallback:(CADisplayLink*)sender
#elif defined( CINDER_COCOA )
- (void)displayLinkCallback:(CVDisplayLinkRef*)sender
#endif
{
#if defined( CINDER_COCOA_TOUCH )
    self->responder->playerUpdateFrame();
#endif
    
	/*
	 CMTime outputItemTime = kCMTimeInvalid;
	 
	 // Calculate the nextVsync time which is when the screen will be refreshed next.
	 CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
	 
	 outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
	 
	 if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime]) {
	 CVPixelBufferRef pixelBuffer = NULL;
	 pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
	 
	 [[self playerView] displayPixelBuffer:pixelBuffer];
	 }
	 */
}

- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output
{
	self->responder->outputSequenceWasFlushedCallback(output);
}

@end


// this has a conflict with Boost 1.53, so instead just declare the symbol extern
namespace cinder {
	extern void sleep( float milliseconds );
}

namespace cinder { namespace avf {
	
MovieBase::MovieBase()
:	mPlayer(NULL),
	mPlayerItem(NULL),
	mAsset(NULL),
	mPlayerVideoOutput(NULL),
	mPlayerDelegate(NULL),
	mResponder(NULL)
{
	init();
}

MovieBase::~MovieBase()
{
	// remove all observers
	removeObservers();
	
	// release resources for AVF objects.
	if (mPlayer) {
		[mPlayer cancelPendingPrerolls];
		[mPlayer release];
	}
	
	if (mAsset) {
		[mAsset cancelLoading];
		[mAsset release];
	}
}
	
float MovieBase::getPixelAspectRatio() const
{
	float pixelAspectRatio = 1.0;
	
	if (!mAsset) return pixelAspectRatio;
	
	NSArray* video_tracks = [mAsset tracksWithMediaType:AVMediaTypeVideo];
	if (video_tracks) {
		CMFormatDescriptionRef format_desc = NULL;
		NSArray* descriptions_arr = [[video_tracks objectAtIndex:0] formatDescriptions];
		if ([descriptions_arr count] > 0)
			format_desc = (CMFormatDescriptionRef)[descriptions_arr objectAtIndex:0];
		
		CGSize size;
		if (format_desc)
			size = CMVideoFormatDescriptionGetPresentationDimensions(format_desc, false, false);
		else
			size = [[video_tracks objectAtIndex:0] naturalSize];
		
		CFDictionaryRef pixelAspectRatioDict = (CFDictionaryRef) CMFormatDescriptionGetExtension(format_desc, kCMFormatDescriptionExtension_PixelAspectRatio);
		if (pixelAspectRatioDict) {
			CFNumberRef horizontal = (CFNumberRef) CFDictionaryGetValue(pixelAspectRatioDict, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing);//, AVVideoPixelAspectRatioHorizontalSpacingKey,
			CFNumberRef vertical = (CFNumberRef) CFDictionaryGetValue(pixelAspectRatioDict, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing);//, AVVideoPixelAspectRatioVerticalSpacingKey,
			float x_value, y_value;
			if (horizontal && vertical) {
				if (CFNumberGetValue(horizontal, kCFNumberFloat32Type, &x_value) &&
					CFNumberGetValue(vertical, kCFNumberFloat32Type, &y_value))
				{
					pixelAspectRatio = x_value / y_value;
				}
			}
		}
	}
	
	return pixelAspectRatio;
}

bool MovieBase::checkPlayThroughOk()
{
	mPlayThroughOk = [mPlayerItem isPlaybackLikelyToKeepUp];
	
	return mPlayThroughOk;
}

int32_t MovieBase::getNumFrames()
{
	if (mFrameCount <= 0)
		mFrameCount = countFrames();
	
	return mFrameCount;
}

bool MovieBase::checkNewFrame()
{
	if (!mPlayer || !mPlayerVideoOutput) return false;
	
	bool result;
	
	lock();
	if (mPlayerVideoOutput) {
		result = [mPlayerVideoOutput hasNewPixelBufferForItemTime:[mPlayer currentTime]];
	}
	else {
		result = false;
	}
	unlock();
	
	return result;
}

float MovieBase::getCurrentTime() const
{
	if (!mPlayer) return -1;
	
	return CMTimeGetSeconds([mPlayer currentTime]);
}

void MovieBase::seekToTime( float seconds )
{
	if (!mPlayer) return;
	
	CMTime seek_time = CMTimeMakeWithSeconds(seconds, [mPlayer currentTime].timescale);
	[mPlayer seekToTime:seek_time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

void MovieBase::seekToFrame( int frame )
{
	if (!mPlayer) return;
	
	CMTime currentTime = [mPlayer currentTime];
	CMTime oneFrame = CMTimeMakeWithSeconds(1.0 / mFrameRate, currentTime.timescale);
	CMTime startTime = kCMTimeZero;
	CMTime addedFrame = CMTimeMultiply(oneFrame, frame);
	CMTime added = CMTimeAdd(startTime, addedFrame);
	
	[mPlayer seekToTime:added toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

void MovieBase::seekToStart()
{
	if (!mPlayer) return;
	
	[mPlayer seekToTime:kCMTimeZero];
}

void MovieBase::seekToEnd()
{
	if (!mPlayer || !mPlayerItem) return;
	
	if (mPlayingForward) {
		[mPlayer seekToTime:[mPlayerItem forwardPlaybackEndTime]];
	}
	else {
		[mPlayer seekToTime:[mPlayerItem reversePlaybackEndTime]];
	}
}

void MovieBase::setActiveSegment( float startTime, float duration )
{
	if (!mPlayer || !mPlayerItem) return;
	
	int32_t scale = [mPlayer currentTime].timescale;
	CMTime cm_start = CMTimeMakeWithSeconds(startTime, scale);
	CMTime cm_duration = CMTimeMakeWithSeconds(startTime + duration, scale);
	
	if (mPlayingForward) {
		[mPlayer seekToTime:cm_start];
		[mPlayerItem setForwardPlaybackEndTime:cm_duration];
	}
	else {
		[mPlayer seekToTime:cm_duration];
		[mPlayerItem setReversePlaybackEndTime:cm_start];
	}
}

void MovieBase::resetActiveSegment()
{
	if (!mPlayer || !mPlayerItem) return;
	
	if (mPlayingForward) {
		[mPlayer seekToTime:kCMTimeZero];
		[mPlayerItem setForwardPlaybackEndTime:[mPlayerItem duration]];
	}
	else {
		[mPlayer seekToTime:[mPlayerItem duration]];
		[mPlayerItem setReversePlaybackEndTime:kCMTimeZero];
	}
}

void MovieBase::setLoop( bool loop, bool palindrome )
{
	mLoop = loop;
	mPalindrome = (loop? palindrome: false);
}

bool MovieBase::stepForward()
{
	if (!mPlayerItem) return false;
	
	bool can_step_forwards = [mPlayerItem canStepForward];
	if (can_step_forwards) {
		[mPlayerItem stepByCount:1];
	}
	
	return can_step_forwards;
}

bool MovieBase::stepBackward()
{
	if (!mPlayerItem) return false;
	
	bool can_step_backwards = [mPlayerItem canStepBackward];
	
	if (can_step_backwards) {
		[mPlayerItem stepByCount:-1];
	}
	
	return can_step_backwards;
}

bool MovieBase::setRate( float rate )
{
	if (!mPlayer || !mPlayerItem) return false;
	
	bool success = false;
	
	if (rate < -1.0f) {
		success = [mPlayerItem canPlayFastReverse];
	} else if (rate < 0.0f) {
		success = [mPlayerItem canPlaySlowReverse];
	} else if (rate > 1.0f) {
		success = [mPlayerItem canPlayFastForward];
	} else if (rate > 0.0f) {
		success = [mPlayerItem canPlaySlowForward];
	}
	
	[mPlayer setRate:rate];
	
	return success;
}

void MovieBase::setVolume( float volume )
{
	if (!mPlayer) return;
	
#if defined( CINDER_COCOA_TOUCH )
	NSArray* audioTracks = [mAsset tracksWithMediaType:AVMediaTypeAudio];
	NSMutableArray* allAudioParams = [NSMutableArray array];
	for (AVAssetTrack *track in audioTracks) {
		AVMutableAudioMixInputParameters* audioInputParams =[AVMutableAudioMixInputParameters audioMixInputParameters];
		[audioInputParams setVolume:volume atTime:kCMTimeZero];
		[audioInputParams setTrackID:[track trackID]];
		[allAudioParams addObject:audioInputParams];
	}
	AVMutableAudioMix* volumeMix = [AVMutableAudioMix audioMix];
	[volumeMix setInputParameters:allAudioParams];
	[mPlayerItem setAudioMix:volumeMix];
	
#elif defined( CINDER_COCOA )
	[mPlayer setVolume:volume];
	
#endif
}

float MovieBase::getVolume() const
{
	if (!mPlayer) return -1;
	
#if defined( CINDER_COCOA_TOUCH )
	AVMutableAudioMix* mix = (AVMutableAudioMix*) [mPlayerItem audioMix];
	NSArray* inputParams = [mix inputParameters];
	float startVolume, endVolume;
	bool success = false;
	for (AVAudioMixInputParameters* param in inputParams) {
		success = [param getVolumeRampForTime:[mPlayerItem currentTime] startVolume:&startVolume endVolume:&endVolume timeRange:NULL] || success;
	}
	if (!success) return -1;
	else return endVolume;
	
#elif defined( CINDER_COCOA )
	return [mPlayer volume];
	
#endif
}

bool MovieBase::isPlaying() const
{
	if (!mPlayer) return false;
	
	return [mPlayer rate] != 0;
}

bool MovieBase::isDone() const
{
	if (!mPlayerItem) return false;
	
	CMTime current_time = [mPlayerItem currentTime];
	CMTime end_time = (mPlayingForward? [mPlayerItem duration]: kCMTimeZero);
	return CMTimeCompare(current_time, end_time) >= 0;
}

void MovieBase::play(bool toggle)
{
	if (!mPlayer) {
		mPlaying = true;
		return;
	}
	
	if (toggle) {
		isPlaying()? [mPlayer pause]: [mPlayer play];
	}
	else {
		[mPlayer play];
	}
}

void MovieBase::stop()
{
	mPlaying = false;
	
	if (!mPlayer)
		return;
	
	[mPlayer pause];
}

void MovieBase::init()
{
	mHasAudio = mHasVideo = false;
	mPlayThroughOk = mPlayable = mProtected = false;
	mPlaying = mPlayingForward = true;
	mLoop = mPalindrome = false;
	mFrameRate = -1;
	mWidth = -1;
	mHeight = -1;
	mDuration = -1;
	mFrameCount = -1;
}
    
void MovieBase::initFromUrl( const Url& url )
{
	NSURL* asset_url = [NSURL URLWithString:[NSString stringWithCString:url.c_str() encoding:[NSString defaultCStringEncoding]]];
	if (!asset_url)
		throw AvfUrlInvalidExc();
	
	// Create the AVAsset
	NSDictionary* asset_options = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)};
	mAsset = [[AVURLAsset alloc] initWithURL:asset_url options:asset_options];
	
	mResponder = new MovieResponder(this);
	mPlayerDelegate = [[MovieDelegate alloc] initWithResponder:mResponder];
	
	loadAsset();
}

void MovieBase::initFromPath( const fs::path& filePath )
{
	NSURL* asset_url = [NSURL fileURLWithPath:[NSString stringWithCString:filePath.c_str() encoding:[NSString defaultCStringEncoding]]];
	if (!asset_url)
		throw AvfPathInvalidExc();
	
	// Create the AVAsset
	NSDictionary* asset_options = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)};
	mAsset = [[AVURLAsset alloc] initWithURL:asset_url options:asset_options];
	
	mResponder = new MovieResponder(this);
	mPlayerDelegate = [[MovieDelegate alloc] initWithResponder:mResponder];
	
	loadAsset();
}

void MovieBase::initFromLoader( const MovieLoader& loader )
{
	if (!loader.ownsMovie()) return;
	
	loader.waitForLoaded();
	mPlayer = loader.transferMovieHandle();
	mPlayerItem = [mPlayer currentItem];
	mAsset = reinterpret_cast<AVURLAsset*>([mPlayerItem asset]);
	
	mResponder = new MovieResponder(this);
	mPlayerDelegate = [[MovieDelegate alloc] initWithResponder:mResponder];

	// process asset and prepare for playback...
	processAsssetTracks(mAsset);
	
	// collect asset information
	mLoaded = true;
	mDuration = (float) CMTimeGetSeconds([mAsset duration]);
	mPlayable = [mAsset isPlayable];
	mProtected = [mAsset hasProtectedContent];
	mPlayThroughOk = [mPlayerItem isPlaybackLikelyToKeepUp];
	
	// setup PlayerItemVideoOutput --from which we will obtain direct texture access
	createPlayerItemOutput(mPlayerItem);
	
	// without this the player continues to move the playhead past the asset duration time...
	[mPlayer setActionAtItemEnd:AVPlayerActionAtItemEndPause];
	
	addObservers();
	
	allocateVisualContext();
}

void MovieBase::loadAsset()
{
	NSArray* keyArray = [NSArray arrayWithObjects:@"tracks", @"duration", @"playable", @"hasProtectedContent", nil];
	[mAsset loadValuesAsynchronouslyForKeys:keyArray completionHandler:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			mLoaded = true;
			
			NSError* error = nil;
			AVKeyValueStatus status = [mAsset statusOfValueForKey:@"tracks" error:&error];
			if (status == AVKeyValueStatusLoaded && !error) {
				processAsssetTracks(mAsset);
			} else {
                ci::app::console() << "AVKeyValueStatusLoaded error -- tracks" << std::endl;
            }
			
			error = nil;
			status = [mAsset statusOfValueForKey:@"duration" error:&error];
			if (status == AVKeyValueStatusLoaded && !error) {
				mDuration = (float) CMTimeGetSeconds([mAsset duration]);
			} else {
                ci::app::console() << "AVKeyValueStatusLoaded error -- duration" << std::endl;
            }
			
			error = nil;
			status = [mAsset statusOfValueForKey:@"playable" error:&error];
			if (status == AVKeyValueStatusLoaded && !error) {
				mPlayable = [mAsset isPlayable];
			} else {
                ci::app::console() << "AVKeyValueStatusLoaded error -- playable" << std::endl;
            }
			
			error = nil;
			status = [mAsset statusOfValueForKey:@"hasProtectedContent" error:&error];
			if (status == AVKeyValueStatusLoaded && !error) {
				mProtected = [mAsset hasProtectedContent];
			} else {
                ci::app::console() << "AVKeyValueStatusLoaded error -- hasProtectedContent" << std::endl;
            }
			
			// Create a new AVPlayerItem and make it our player's current item.
			mPlayer = [[AVPlayer alloc] init];
			mPlayerItem = [AVPlayerItem playerItemWithAsset:mAsset];
			[mPlayer replaceCurrentItemWithPlayerItem:mPlayerItem];
			
			// setup PlayerItemVideoOutput --from which we will obtain direct texture access
			createPlayerItemOutput(mPlayerItem);
			
			// without this the player continues to move the playhead past the asset duration time...
			[mPlayer setActionAtItemEnd:AVPlayerActionAtItemEndPause];
			
			addObservers();
			
			allocateVisualContext();
		});
	}];
}

void MovieBase::updateFrame()
{
//	lock();
	if (mPlayerVideoOutput && mPlayerItem) {
		if ([mPlayerVideoOutput hasNewPixelBufferForItemTime:[mPlayerItem currentTime]]) {
			releaseFrame();
			
			CVImageBufferRef buffer = nil;
			buffer = [mPlayerVideoOutput copyPixelBufferForItemTime:[mPlayerItem currentTime] itemTimeForDisplay:nil];
			if (buffer) {
				newFrame(buffer);
				mSignalNewFrame();
			}
		}
	}
//	unlock();
}

uint32_t MovieBase::countFrames() const
{
	if (!mAsset) return 0;
	
	CMTime dur = [mAsset duration];
	CMTime one_frame = CMTimeMakeWithSeconds(1.0 / mFrameRate, dur.timescale);
	double dur_seconds = CMTimeGetSeconds(dur);
	double one_frame_seconds = CMTimeGetSeconds(one_frame);
	return static_cast<uint32_t>(dur_seconds / one_frame_seconds);
}

void MovieBase::processAsssetTracks(AVAsset* asset)
{
	// process video tracks
	NSArray* video_tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
	mHasVideo = [video_tracks count] > 0;
	if (mHasVideo) {
		AVAssetTrack* video_track = [video_tracks objectAtIndex:0];
		if (video_track) {
			// Grab track dimensions from format description
			CGSize size = [video_track naturalSize];
			CGAffineTransform trans = [video_track preferredTransform];
			size = CGSizeApplyAffineTransform(size, trans);
			mHeight = static_cast<int32_t>(size.height);
			mWidth = static_cast<int32_t>(size.width);
			mFrameRate = [video_track nominalFrameRate];
		}
		else throw AvfFileInvalidExc();
	}
	
	// process audio tracks
	NSArray* audio_tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
	mHasAudio = [audio_tracks count] > 0;
#if defined( CINDER_COCOA_TOUCH )
	if (mHasAudio) {
		setAudioSessionModes();
	}
#elif defined( CINDER_COCOA )
	// No need for changes on OSX
	
#endif
}

void MovieBase::createPlayerItemOutput(const AVPlayerItem* playerItem)
{
	NSDictionary* pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
	mPlayerVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
	[mPlayerVideoOutput setDelegate:mPlayerDelegate queue:dispatch_queue_create("movieVideoOutputQueue", DISPATCH_QUEUE_SERIAL)];
	[playerItem addOutput:mPlayerVideoOutput];
}

void MovieBase::addObservers()
{
	if (mPlayerDelegate && mPlayerItem) {
		// Determine if this is all we need out of the NotificationCenter
		NSNotificationCenter* notification_center = [NSNotificationCenter defaultCenter];
		[notification_center addObserver:mPlayerDelegate
								selector:@selector(playerItemDidNotReachEndCallback)
									name:AVPlayerItemFailedToPlayToEndTimeNotification
								  object:mPlayerItem];
		
		[notification_center addObserver:mPlayerDelegate
								selector:@selector(playerItemDidReachEndCallback)
									name:AVPlayerItemDidPlayToEndTimeNotification
								  object:mPlayerItem];
		
		[notification_center addObserver:mPlayerDelegate
								selector:@selector(playerItemTimeJumpedCallback)
									name:AVPlayerItemTimeJumpedNotification
								  object:mPlayerItem];
		
		[mPlayerItem addObserver:mPlayerDelegate
					  forKeyPath:@"status"
						 options:nil
						 context:AVPlayerItemStatusContext];
	}
}

void MovieBase::removeObservers()
{    
	if (mPlayerDelegate && mPlayerItem) {
		NSNotificationCenter* notify_center = [NSNotificationCenter defaultCenter];
		[notify_center removeObserver:mPlayerDelegate
								 name:AVPlayerItemFailedToPlayToEndTimeNotification
							   object:mPlayerItem];
		
		[notify_center removeObserver:mPlayerDelegate
								 name:AVPlayerItemDidPlayToEndTimeNotification
							   object:mPlayerItem];
		
		[notify_center removeObserver:mPlayerDelegate
								 name:AVPlayerItemTimeJumpedNotification
							   object:mPlayerItem];
		
		[mPlayerItem removeObserver:mPlayerDelegate
						 forKeyPath:@"status"];
	}
}
	
void MovieBase::playerReady()
{
	mSignalReady();
	
	if (mPlaying) play();
}
	
void MovieBase::playerItemEnded()
{
	if (mPalindrome) {
		float rate = -[mPlayer rate];
		mPlayingForward = (rate >= 0);
		this->setRate(rate);
	}
	else if (mLoop) {
		this->seekToStart();
	}
	
	mSignalEnded();
}
	
void MovieBase::playerItemCancelled()
{
	mSignalCancelled();
}
	
void MovieBase::playerItemJumped()
{
	mSignalJumped();
}

void MovieBase::outputWasFlushed(AVPlayerItemOutput* output)
{
	mSignalOutputWasFlushed();
}

/////////////////////////////////////////////////////////////////////////////////
// MovieSurface
MovieSurface::MovieSurface( const Url& url ) : MovieBase()
{
	MovieBase::initFromUrl( url );
}

MovieSurface::MovieSurface( const fs::path& path ) : MovieBase()
{
	MovieBase::initFromPath( path );
}

MovieSurface::MovieSurface( const MovieLoader& loader ) : MovieBase()
{
	MovieBase::initFromLoader( loader );
}

MovieSurface::~MovieSurface()
{
	deallocateVisualContext();
}
		
bool MovieSurface::hasAlpha() const
{
	if (mPlayerVideoOutput && mPlayer && [mPlayerVideoOutput hasNewPixelBufferForItemTime:[mPlayer currentTime]]) {
		CVImageBufferRef pixel_buffer = nil;
		pixel_buffer = [mPlayerVideoOutput copyPixelBufferForItemTime:[mPlayerItem currentTime] itemTimeForDisplay:nil];
		if ( pixel_buffer != nil ) {
			CVPixelBufferLockBaseAddress( pixel_buffer, 0 );
			OSType type = CVPixelBufferGetPixelFormatType(pixel_buffer);
			CVPixelBufferUnlockBaseAddress( pixel_buffer, 0 );
#if defined ( CINDER_COCOA_TOUCH)
			return (type == kCVPixelFormatType_32ARGB ||
					type == kCVPixelFormatType_32BGRA ||
					type == kCVPixelFormatType_32ABGR ||
					type == kCVPixelFormatType_32RGBA ||
					type == kCVPixelFormatType_64ARGB);
#elif defined ( CINDER_COCOA )
			return (type == k32ARGBPixelFormat || type == k32BGRAPixelFormat);
#endif
			
		}
	}
	
	return mSurface.hasAlpha();
}

Surface MovieSurface::getSurface()
{
#if defined( CINDER_COCOA_TOUCH )
#elif defined( CINDER_COCOA )
    updateFrame();
#endif
	
//	lock();
	Surface result = mSurface;
//	unlock();
	
	return result;
}

void MovieSurface::newFrame( CVImageBufferRef cvImage )
{
	CVPixelBufferRef imgRef = reinterpret_cast<CVPixelBufferRef>( cvImage );
	if( imgRef ) {
		mSurface = convertCvPixelBufferToSurface( imgRef );
	}
	else
		mSurface.reset();
}

void MovieSurface::releaseFrame()
{
	mSurface.reset();
}

/////////////////////////////////////////////////////////////////////////////////
// MovieGl
MovieGl::MovieGl( const Url& url ) : MovieBase(), mVideoTextureRef(NULL), mVideoTextureCacheRef(NULL)
{    
	MovieBase::initFromUrl( url );
}

MovieGl::MovieGl( const fs::path& path ) : MovieBase(), mVideoTextureRef(NULL), mVideoTextureCacheRef(NULL)
{
	MovieBase::initFromPath( path );
}
	
MovieGl::MovieGl( const MovieLoader& loader ) : MovieBase(), mVideoTextureRef(NULL), mVideoTextureCacheRef(NULL)
{
	MovieBase::initFromLoader(loader);
}
		
MovieGl::~MovieGl()
{
	deallocateVisualContext();
}
	
bool MovieGl::hasAlpha() const
{
	if (!mVideoTextureRef) return false;
	
	CVPixelBufferLockBaseAddress( mVideoTextureRef, 0 );
	OSType type = CVPixelBufferGetPixelFormatType(mVideoTextureRef);
	CVPixelBufferUnlockBaseAddress( mVideoTextureRef, 0 );
#if defined ( CINDER_COCOA_TOUCH)
	return (type == kCVPixelFormatType_32ARGB ||
			type == kCVPixelFormatType_32BGRA ||
			type == kCVPixelFormatType_32ABGR ||
			type == kCVPixelFormatType_32RGBA ||
			type == kCVPixelFormatType_64ARGB);
#elif defined ( CINDER_COCOA )
	return (type == k32ARGBPixelFormat || type == k32BGRAPixelFormat);
#endif
	
	/*
	CGColorSpaceRef color_space = CVImageBufferGetColorSpace(mVideoTextureRef);
	size_t components = CGColorSpaceGetNumberOfComponents(color_space);
	return components > 3;
	*/
}

const gl::Texture MovieGl::getTexture()
{
	updateFrame();
	
	lock();
	gl::Texture result = mTexture;
	unlock();
	
	return result;
}
	
void MovieGl::allocateVisualContext()
{
	if(mVideoTextureCacheRef == NULL) {
		CVReturn err = nil;
#if defined( CINDER_COCOA_TOUCH )
		ci::app::RendererGlRef renderer = std::dynamic_pointer_cast<ci::app::RendererGl>(app::App::get()->getRenderer());
		EAGLContext* context = renderer->getEaglContext();
		err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &mVideoTextureCacheRef);
		
#elif defined( CINDER_COCOA )
		CGLContextObj context = app::App::get()->getRenderer()->getCglContext();
		CGLPixelFormatObj pixelFormat = app::App::get()->getRenderer()->getCglPixelFormat();
		err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, context, pixelFormat, NULL, &mVideoTextureCacheRef);
		CVOpenGLTextureCacheRetain(mVideoTextureCacheRef);
		
#endif
		if (err) throw AvfTextureErrorExc();
	}
}

void MovieGl::deallocateVisualContext()
{
	if(mVideoTextureRef) {
		CFRelease(mVideoTextureRef);
		mVideoTextureRef = NULL;
	}
	
	if(mVideoTextureCacheRef) {
#if defined( CINDER_COCOA_TOUCH )
		CVOpenGLESTextureCacheFlush(mVideoTextureCacheRef, 0);
#elif defined( CINDER_COCOA )
		CVOpenGLTextureCacheFlush(mVideoTextureCacheRef, 0);
#endif
		CFRelease(mVideoTextureCacheRef);
		mVideoTextureCacheRef = NULL;
	}
}

void MovieGl::newFrame( CVImageBufferRef cvImage )
{
	CVPixelBufferLockBaseAddress(cvImage, kCVPixelBufferLock_ReadOnly);
	
	if (mVideoTextureRef) {
		CFRelease(mVideoTextureRef);
		mVideoTextureRef = NULL;
	}
#if defined( CINDER_COCOA_TOUCH )
	CVOpenGLESTextureCacheFlush(mVideoTextureCacheRef, 0); // Periodic texture cache flush every frame
#elif defined( CINDER_COCOA )
	CVOpenGLTextureCacheFlush(mVideoTextureCacheRef, 0); // Periodic texture cache flush every frame
#endif
	
	CVReturn err = nil;
	
#if defined( CINDER_COCOA_TOUCH )
	err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,     // CFAllocatorRef allocator
													   mVideoTextureCacheRef,   // CVOpenGLESTextureCacheRef textureCache
													   cvImage,                 // CVImageBufferRef sourceImage
													   NULL,                    // CFDictionaryRef textureAttributes
													   GL_TEXTURE_2D,           // GLenum target
													   GL_RGBA,                 // GLint internalFormat
													   mWidth,                  // GLsizei width
													   mHeight,                 // GLsizei height
													   GL_BGRA,                 // GLenum format
													   GL_UNSIGNED_BYTE,        // GLenum type
													   0,                       // size_t planeIndex
													   &mVideoTextureRef);      // CVOpenGLESTextureRef *textureOut
	
#elif defined( CINDER_MAC )
	err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault,       // CFAllocatorRef allocator
													 mVideoTextureCacheRef,     // CVOpenGLESTextureCacheRef textureCache
													 cvImage,                   // CVImageBufferRef sourceImage
													 NULL,                      // CFDictionaryRef textureAttributes
													 &mVideoTextureRef);        // CVOpenGLTextureRef *textureOut
#endif
	
	if (err) {
		throw AvfTextureErrorExc();
		return;
	}
	
#if defined( CINDER_COCOA_TOUCH )
	GLenum target = CVOpenGLESTextureGetTarget( mVideoTextureRef );
	GLuint name = CVOpenGLESTextureGetName( mVideoTextureRef );
	bool flipped = !CVOpenGLESTextureIsFlipped( mVideoTextureRef );
	mTexture = gl::Texture( target, name, mWidth, mHeight, true );
	Vec2f t0, lowerRight, t2, upperLeft;
	::CVOpenGLESTextureGetCleanTexCoords( mVideoTextureRef, &t0.x, &lowerRight.x, &t2.x, &upperLeft.x );
	mTexture.setCleanTexCoords( std::max( upperLeft.x, lowerRight.x ), std::max( upperLeft.y, lowerRight.y ) );
	mTexture.setFlipped( flipped );
	
#elif defined( CINDER_MAC )	
	GLenum target = CVOpenGLTextureGetTarget( mVideoTextureRef );
	GLuint name = CVOpenGLTextureGetName( mVideoTextureRef );
	bool flipped = ! CVOpenGLTextureIsFlipped( mVideoTextureRef );
	mTexture = gl::Texture( target, name, mWidth, mHeight, true );
	Vec2f t0, lowerRight, t2, upperLeft;
	CVOpenGLTextureGetCleanTexCoords( mVideoTextureRef, &t0.x, &lowerRight.x, &t2.x, &upperLeft.x );
	mTexture.setCleanTexCoords( std::max( upperLeft.x, lowerRight.x ), std::max( upperLeft.y, lowerRight.y ) );
	mTexture.setFlipped( flipped );
	//mTexture.setDeallocator( CVPixelBufferDealloc, mVideoTextureRef );	// do we want to do this?
	
#endif

	CVPixelBufferUnlockBaseAddress(cvImage, kCVPixelBufferLock_ReadOnly);
	CVPixelBufferRelease(cvImage);
}

void MovieGl::releaseFrame()
{
	mTexture.reset();
}

/////////////////////////////////////////////////////////////////////////////////
// MovieLoader
MovieLoader::MovieLoader( const Url &url )
:	mUrl(url), mBufferFull(false), mBufferEmpty(false), mLoaded(false),
	mPlayable(false), mPlayThroughOK(false), mProtected(false), mOwnsMovie(true)
{
	NSURL* asset_url = [NSURL URLWithString:[NSString stringWithCString:mUrl.c_str() encoding:[NSString defaultCStringEncoding]]];
	if (!asset_url)
		throw AvfUrlInvalidExc();
	
	AVPlayerItem* playerItem = [[AVPlayerItem alloc] initWithURL:asset_url];
	mPlayer = [[AVPlayer alloc] init];
	[mPlayer replaceCurrentItemWithPlayerItem:playerItem];	// starts the downloading process
}

MovieLoader::~MovieLoader()
{
	if( mOwnsMovie && mPlayer ) {
		[mPlayer release];
	}
}
	
bool MovieLoader::checkLoaded() const
{
	if( !mLoaded )
		updateLoadState();
	
	return mLoaded;
}

bool MovieLoader::checkPlayable() const
{
	if( !mPlayable )
		updateLoadState();
	
	return mPlayable;
}

bool MovieLoader::checkPlayThroughOk() const
{
	if( !mPlayThroughOK )
		updateLoadState();
	
	return mPlayThroughOK;
}

bool MovieLoader::checkProtection() const
{
	updateLoadState();
	
	return mProtected;
}

void MovieLoader::waitForLoaded() const
{
	// Accessing the AVAssets properties (such as duration, tracks, etc) will block the thread until they're available...
	NSArray* video_tracks = [[[mPlayer currentItem] asset] tracksWithMediaType:AVMediaTypeVideo];
	mLoaded = [video_tracks count] > 0;
}

void MovieLoader::waitForPlayable() const
{
	while( !mPlayable ) {
		cinder::sleep( 250 );
		updateLoadState();
	}
}

void MovieLoader::waitForPlayThroughOk() const
{
	while( !mPlayThroughOK ) {
		cinder::sleep( 250 );
		updateLoadState();
	}
}

void MovieLoader::updateLoadState() const
{    
	AVPlayerItem* playerItem = [mPlayer currentItem];
	mLoaded = mPlayable = [playerItem status] == AVPlayerItemStatusReadyToPlay;
	mPlayThroughOK = [playerItem isPlaybackLikelyToKeepUp];
	mProtected = [[playerItem asset] hasProtectedContent];
	app::console() << "  loaded: " << mLoaded << std::endl;
	app::console() << "  protected: " << mProtected << std::endl;
	app::console() << "  playback okay?: " << mPlayThroughOK << std::endl;
	
	//NSArray* loaded = [playerItem seekableTimeRanges];  // this value appears to be garbage (wtf?)
//	NSArray* loaded = [playerItem loadedTimeRanges];      // this value appears to be garbage (wtf?)
//	for (NSValue* value in loaded) {
//		CMTimeRange range = [value CMTimeRangeValue];
//		float start = CMTimeGetSeconds(range.start);
//		float dur = CMTimeGetSeconds(range.duration);
		//mLoaded = (CMTimeCompare([playerItem duration], range.duration) >= 0);
//	}
	
	AVPlayerItemAccessLog* log = [playerItem accessLog];
	if (log) {
		NSArray* load_events = [log events];
		for (AVPlayerItemAccessLogEvent* log_event in load_events) {
			int segemnts = log_event.numberOfSegmentsDownloaded;
			int stalls = log_event.numberOfStalls;							// only accurate if playing!
			double segment_interval = log_event.segmentsDownloadedDuration;	// only accurate if playing!
			double watched_interval = log_event.durationWatched;			// only accurate if playing!
			NSString* str = log_event.serverAddress;
			std::string address = (str? std::string([str UTF8String]): "");
			long long bytes_transfered = log_event.numberOfBytesTransferred;
			double bitrate = log_event.observedBitrate;
			int dropped_frames = log_event.numberOfDroppedVideoFrames;		// only accurate if playing!
			
			app::console() << "-------------------------" << std::endl;
			app::console() << "  segments: " << segemnts << std::endl;
			app::console() << "  stalls: " << stalls << std::endl;
			app::console() << "  segment_interval: " << segment_interval << std::endl;
			app::console() << "  watched_interval: " << watched_interval << std::endl;
			app::console() << "  address: " << address << std::endl;
			app::console() << "  bytes_transfered: " << bytes_transfered << std::endl;
			app::console() << "  bitrate: " << bitrate << std::endl;
			app::console() << "  dropped_frames: " << dropped_frames << std::endl;
			app::console() << "  COMPLETLEY LOADED?: " << (segment_interval >= 0) << std::endl;
		}
	}
}

} /* namespace avf */ } /* namespace cinder */