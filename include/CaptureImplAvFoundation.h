
#pragma once

#include <vector>

#import <AVFoundation/AVFoundation.h>

#include "cinder/Cinder.h"
#include "cinder/Surface.h"
#include "cinder/Capture.h"

namespace cinder { namespace avf {

class CaptureImplAvFoundationDevice : public Capture::Device {
  public:
	CaptureImplAvFoundationDevice( AVCaptureDevice *device );
	~CaptureImplAvFoundationDevice();
	
	bool						checkAvailable() const;
	bool						isConnected() const;
	Capture::DeviceIdentifier	getUniqueId() const { return mUniqueId; }
	bool						isFrontFacing() const { return mFrontFacing; }
	void*						getNative() const { return mNativeDevice; }
  private:
	Capture::DeviceIdentifier	mUniqueId;
	AVCaptureDevice				*mNativeDevice;
	bool						mFrontFacing;
};

} } // namespace

@interface CaptureImplAvFoundation : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
	AVCaptureSession				*mSession;
	CVPixelBufferRef				mWorkingPixelBuffer;
	cinder::Surface8u				mCurrentFrame;
	NSString						*mDeviceUniqueId;
	
	cinder::Capture::DeviceRef		mDevice;
	bool							mHasNewFrame;
	bool							mIsCapturing;
	int32_t							mWidth, mHeight;
	int32_t							mSurfaceChannelOrderCode;
	int32_t							mExposedFrameBytesPerRow;
	int32_t							mExposedFrameHeight;
	int32_t							mExposedFrameWidth;
}

+ (const std::vector<cinder::Capture::DeviceRef>&)getDevices:(BOOL)forceRefresh;

- (id)initWithDevice:(const cinder::Capture::DeviceRef)device width:(int)width height:(int)height;
- (bool)prepareStartCapture;
- (void)startCapture;
- (void)stopCapture;
- (bool)isCapturing;
- (cinder::Surface8u)getCurrentFrame;
- (bool)checkNewFrame;
- (const cinder::Capture::DeviceRef)getDevice;
- (int32_t)getWidth;
- (int32_t)getHeight;
- (int32_t)getCurrentFrameBytesPerRow;
- (int32_t)getCurrentFrameWidth;
- (int32_t)getCurrentFrameHeight;

@end