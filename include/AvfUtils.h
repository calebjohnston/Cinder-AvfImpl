#pragma once

#include "cinder/Cinder.h"
#include "cinder/Url.h"
#include "cinder/Surface.h"
#include "cinder/ImageIo.h"

#include <string>

#if defined( CINDER_COCOA )
	#include <CoreVideo/CoreVideo.h>
#endif

namespace cinder { namespace avf {

bool setAudioSessionModes();
bool dictionarySetValue( CFMutableDictionaryRef dict, CFStringRef key, SInt32 value );
bool dictionarySetPixelBufferPixelFormatType( bool alpha, CFMutableDictionaryRef dict );
bool dictionarySetPixelBufferSize( const unsigned int width, const unsigned int height, CFMutableDictionaryRef dict );
bool dictionarySetPixelBufferBytesPerRowAlignment( CFMutableDictionaryRef dict );
void dictionarySetPixelBufferOpenGLCompatibility( CFMutableDictionaryRef dict );
bool dictionarySetPixelBufferOptions( unsigned int width, unsigned int height, bool alpha, CFMutableDictionaryRef *pixelBufferOptions );
CFMutableDictionaryRef initQTVisualContextOptions( int width, int height, bool alpha );

//! Designed to be the deallocator for surfaces returned by convertToPixelBufferToSurface
static void CVPixelBufferDealloc( void *refcon );
//! Makes a cinder::Surface form a CVPixelBufferRef, setting a proper deallocation function to free the CVPixelBufferRef upon the destruction of the Surface::Obj
Surface8u convertCvPixelBufferToSurface( CVPixelBufferRef pixelBufferRef );
Surface8u convertCmSampleBufferToSurface( CMSampleBufferRef sampleBufferRef );
CMSampleBufferRef convertSurfaceToCmSampleBuffer( Surface8u surface );

typedef std::shared_ptr<class ImageTargetCvPixelBuffer> ImageTargetCvPixelBufferRef;

class ImageTargetCvPixelBuffer : public cinder::ImageTarget {
  public:
	static ImageTargetCvPixelBufferRef createRef( ImageSourceRef imageSource, bool convertToYpCbCr = false );
	~ImageTargetCvPixelBuffer();

	virtual void*		getRowPointer( int32_t row );
	virtual void		finalize();

	::CVPixelBufferRef	getCvPixelBuffer() const { return mPixelBufferRef; }

  protected:
	ImageTargetCvPixelBuffer( ImageSourceRef imageSource, bool convertToYpCbCr );
	
	void		convertDataToYpCbCr();
	void		convertDataToAYpCbCr();

	::CVPixelBufferRef	mPixelBufferRef;
	size_t				mRowBytes;
	uint8_t				*mData;
	bool				mConvertToYpCbCr;
};

//! Creates a CVPixelBufferRef from an ImageSource. Release the result with CVPixelBufferRelease(). If \a convertToYpCbCr the resulting CVPixelBuffer will be in either \c k444YpCbCr8CodecType or \c k4444YpCbCrA8PixelFormat
CVPixelBufferRef createCvPixelBuffer( ImageSourceRef imageSource, bool convertToYpCbCr = false );

} } // namespace cinder::avf
