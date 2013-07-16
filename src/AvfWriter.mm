#include "cinder/app/App.h"
#include "cinder/Utilities.h"

#include "AvfUtils.h"
#include "AvfWriter.h"

namespace cinder { namespace avf {
	

const float PLATFORM_DEFAULT_GAMMA = 2.2f;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MovieWriter::Format

MovieWriter::Format::Format() : mCodec( 'png ' )
{
	initDefaults();
}

MovieWriter::Format::Format( uint32_t codec, float quality ) : mCodec( codec )
{
	initDefaults();
	setQuality( quality );
}

MovieWriter::Format::Format( const ICMCompressionSessionOptionsRef options, uint32_t codec, float quality, float frameRate, bool enableMultiPass )
:	mCodec( codec ), mEnableMultiPass( enableMultiPass )
{
	/* RE-IMPLEMENT
	::ICMCompressionSessionOptionsCreateCopy( NULL, options, &mOptions );
	*/
	
	setQuality( quality );
	setTimeScale( (long)(frameRate * 100) );
	setDefaultDuration( 1.0f / frameRate );
	setGamma( PLATFORM_DEFAULT_GAMMA );
}

MovieWriter::Format::Format( const Format &format )
:	mCodec( format.mCodec ), mTimeBase( format.mTimeBase ), mDefaultTime( format.mDefaultTime ), 
	mGamma( format.mGamma ), mEnableMultiPass( format.mEnableMultiPass ), mQualityFloat( format.mQualityFloat )
{
	/* RE-IMPLEMENT
	::ICMCompressionSessionOptionsCreateCopy( NULL, format.mOptions, &mOptions );
	*/
}

MovieWriter::Format::~Format()
{
	/* RE-IMPLEMENT
	::ICMCompressionSessionOptionsRelease( mOptions );
	*/
}

void MovieWriter::Format::initDefaults()
{
	/* RE-IMPLEMENT
	OSStatus err = ::ICMCompressionSessionOptionsCreate( NULL, &mOptions );
	*/
	mTimeBase = 600;
	mDefaultTime = 1 / 30.0f;
	mGamma = PLATFORM_DEFAULT_GAMMA;
	mEnableMultiPass = false;

	enableTemporal( true );
	enableReordering( true );
	enableFrameTimeChanges( true );
	setQuality( 0.99f );
}

MovieWriter::Format& MovieWriter::Format::setQuality( float quality )
{
	/* RE-IMPLEMENT
	mQualityFloat = constrain<float>( quality, 0, 1 );
	CodecQ compressionQuality = CodecQ(0x00000400 * mQualityFloat);
	OSStatus err = ICMCompressionSessionOptionsSetProperty( mOptions,
                                kQTPropertyClass_ICMCompressionSessionOptions,
                                kICMCompressionSessionOptionsPropertyID_Quality,
                                sizeof(compressionQuality),
                                &compressionQuality );	
	*/
	return *this;
}

bool MovieWriter::Format::isTemporal() const
{
	// RE-IMPLEMENT
	//return ::ICMCompressionSessionOptionsGetAllowTemporalCompression( mOptions );
	
	return false;
}

MovieWriter::Format& MovieWriter::Format::enableTemporal( bool enable )
{
	// RE-IMPLEMENT
	//OSStatus err = ::ICMCompressionSessionOptionsSetAllowTemporalCompression( mOptions, enable );
	return *this;
}

bool MovieWriter::Format::isReordering() const
{
	// RE-IMPLEMENT
	//return ::ICMCompressionSessionOptionsGetAllowFrameReordering( mOptions );

	return false;
}

MovieWriter::Format& MovieWriter::Format::enableReordering( bool enable )
{
	// RE-IMPLEMENT
	///OSStatus err = ::ICMCompressionSessionOptionsSetAllowFrameReordering( mOptions, enable );
	
	return *this;
}

bool MovieWriter::Format::isFrameTimeChanges() const
{
	// RE-IMPLEMENT
	//return ::ICMCompressionSessionOptionsGetAllowFrameTimeChanges( mOptions );
	
	return false;
}

MovieWriter::Format& MovieWriter::Format::enableFrameTimeChanges( bool enable )
{
	// RE-IMPLEMENT
	//OSStatus err = ::ICMCompressionSessionOptionsSetAllowFrameTimeChanges( mOptions, enable );
	
	return *this;
}

int32_t MovieWriter::Format::getMaxKeyFrameRate() const
{
	// RE-IMPLEMENT
	//return ::ICMCompressionSessionOptionsGetMaxKeyFrameInterval( mOptions );
	
	return 0;
}

MovieWriter::Format& MovieWriter::Format::setMaxKeyFrameRate( int32_t rate )
{
	// RE-IMPLEMENT
	//OSStatus err = ::ICMCompressionSessionOptionsSetMaxKeyFrameInterval( mOptions, rate );
	return *this;
}

const MovieWriter::Format& MovieWriter::Format::operator=( const Format &format )
{
	/* RE-IMPLEMENT
	if( mOptions != format.mOptions ) {
		::ICMCompressionSessionOptionsRelease( mOptions );
		::ICMCompressionSessionOptionsCreateCopy( NULL, format.mOptions, &mOptions );
	}
*/

	mCodec = format.mCodec;
	mTimeBase = format.mTimeBase;
	mDefaultTime = format.mDefaultTime;
	mGamma = format.mGamma;
	mEnableMultiPass = format.mEnableMultiPass;

	return *this;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MovieWriter
MovieWriter::MovieWriter( const fs::path &path, int32_t width, int32_t height, const Format &format )
	: mPath( path ), mWidth( width ), mHeight( height ), mFormat( format ), mFinished( false )
{
//	AVFileTypeQuickTimeMovie
//	AVFileTypeMPEG4
//	AVFileTypeAppleM4V
	
	NSString* str;
	NSURL* localOutputURL = [NSURL URLWithString:str];
	NSError* error = nil;
	mWriter = [[AVAssetWriter alloc] initWithURL:localOutputURL fileType:AVFileTypeQuickTimeMovie error:&error];
	
	// Compress to H.264 with the asset writer
	NSDictionary* compressionSettings = nil;
	NSMutableDictionary* videoSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										  AVVideoCodecH264, AVVideoCodecKey,
										  [NSNumber numberWithDouble:mWidth], AVVideoWidthKey,
										  [NSNumber numberWithDouble:mHeight], AVVideoHeightKey,
										  nil];
	if (compressionSettings)
		[videoSettings setObject:compressionSettings forKey:AVVideoCompressionPropertiesKey];
	
	mWriterSink = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
	[mWriter addInput:mWriterSink];
	
	
	/*
    OSErr       err = noErr;
    Handle      dataRef;
    OSType      dataRefType;
 
	startQuickTime();

    //Create movie file
	CFStringRef strDestMoviePath = ::CFStringCreateWithCString( kCFAllocatorDefault, path.string().c_str(), kCFStringEncodingUTF8 );
	err = ::QTNewDataReferenceFromFullPathCFString( strDestMoviePath, kQTNativeDefaultPathStyle, 0, &dataRef, &dataRefType );
	::CFRelease( strDestMoviePath );
	if( err )
        throw MovieWriterExcInvalidPath();

	// Create a movie for this file (data ref)
    err = ::CreateMovieStorage( dataRef, dataRefType, 'TVOD', smCurrentScript, createMovieFileDeleteCurFile | createMovieFileDontCreateResFile, &mDataHandler, &mMovie );
	::DisposeHandle( dataRef );
    if( err )
        throw MovieWriterExc();

	mTrack = ::NewMovieTrack( mMovie, width << 16, height << 16, 0 );
	err = ::GetMoviesError();
	if( err )
		throw MovieWriterExc();
        
	//Create track media
	mMedia = ::NewTrackMedia( mTrack, ::VideoMediaType, mFormat.mTimeBase, 0, 0 );
	err = ::GetMoviesError();
	if( err )
		throw MovieWriterExc();

	//Prepare media for editing
	err = ::BeginMediaEdits( mMedia );

	mRequestedMultiPass = false;
	mDoingMultiPass = false;

	createCompressionSession();

	mCurrentTimeValue = 0;
	mNumFrames = 0;
	*/
}

MovieWriter::~MovieWriter()
{
	if( ! mFinished )
		finish();
}
	
void MovieWriter::addFrame( const ImageSourceRef &imageSource, float duration )
{
	/* RE-IMPLEMENT
	if( mFinished )
		throw MovieWriterExcAlreadyFinished();

	if( duration <= 0 )
		duration = mFormat.mDefaultTime;

	::CVPixelBufferRef pixelBuffer = createCvPixelBuffer( imageSource, false );
	::CFNumberRef gammaLevel = CFNumberCreate( kCFAllocatorDefault, kCFNumberFloatType, &mFormat.mGamma );
	::CVBufferSetAttachment( pixelBuffer, kCVImageBufferGammaLevelKey, gammaLevel, kCVAttachmentMode_ShouldPropagate );
	::CFRelease( gammaLevel );

	::ICMValidTimeFlags validTimeFlags = kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid;
	::ICMCompressionFrameOptionsRef frameOptions = NULL;
	int64_t durationVal = static_cast<int64_t>( duration * mFormat.mTimeBase );
	OSStatus err = ::ICMCompressionSessionEncodeFrame( mCompressionSession, pixelBuffer,
				mCurrentTimeValue, durationVal, validTimeFlags,
                frameOptions, NULL, NULL );

	mFrameTimes.push_back( std::pair<int64_t,int64_t>( mCurrentTimeValue, durationVal ) );

	if( mDoingMultiPass ) {
		mMultiPassFrameCache->write( (uint32_t)::CVPixelBufferGetWidth( pixelBuffer ) );
		mMultiPassFrameCache->write( (uint32_t)::CVPixelBufferGetHeight( pixelBuffer ) );
		mMultiPassFrameCache->write( (uint32_t)::CVPixelBufferGetPixelFormatType( pixelBuffer ) );
		mMultiPassFrameCache->write( (uint32_t)::CVPixelBufferGetBytesPerRow( pixelBuffer ) );
		::CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
		mMultiPassFrameCache->write( (uint32_t) ::CVPixelBufferGetDataSize( pixelBuffer ) );
		mMultiPassFrameCache->writeData( ::CVPixelBufferGetBaseAddress( pixelBuffer ), ::CVPixelBufferGetDataSize( pixelBuffer ) );
		::CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	}

	mCurrentTimeValue += durationVal;
	++mNumFrames;

	::CVPixelBufferRelease( pixelBuffer );

	if( err )
		MovieWriterExcFrameEncode();
	*/
		
}

extern "C" {
OSStatus MovieWriter::encodedFrameOutputCallback( void *refCon, ICMCompressionSessionOptionsRef session,
												OSStatus err, ICMEncodedFrameRef encodedFrame, void *reserved )
{
	/* RE-IMPLEMENT
	MovieWriter::Obj *obj = reinterpret_cast<MovieWriter::Obj*>( refCon );

	ImageDescriptionHandle imageDescription = NULL;
	err = ICMCompressionSessionGetImageDescription( session, &imageDescription );
	if( ! err ) {
		Fixed gammaLevel = qtime::floatToFixed( obj->mFormat.mGamma );
		err = ICMImageDescriptionSetProperty(imageDescription,
						kQTPropertyClass_ImageDescription,
						kICMImageDescriptionPropertyID_GammaLevel,
						sizeof(gammaLevel), &gammaLevel);
		if( err != 0 )
			throw;
	}
	else
		throw;

	OSStatus result = ::AddMediaSampleFromEncodedFrame( obj->mMedia, encodedFrame, NULL );
	return result;
	*/
	
	OSStatus result;
	return result;
}

OSStatus enableMultiPassWithTemporaryFile( ICMCompressionSessionOptionsRef inCompressionSessionOptions, ICMMultiPassStorageRef *outMultiPassStorage )
{
	/* RE-IMPLEMENT
	::ICMMultiPassStorageRef multiPassStorage = NULL;
	OSStatus status;
	*outMultiPassStorage = NULL;

	// create storage using a temporary file with a unique file name
	status = ::ICMMultiPassStorageCreateWithTemporaryFile( kCFAllocatorDefault, NULL, NULL, 0, &multiPassStorage );
	if( noErr != status )
		goto bail;

	// enable multi-pass by setting the compression session options
	// note - the compression session options object retains the multi-pass
	// storage object
	status = ::ICMCompressionSessionOptionsSetProperty( inCompressionSessionOptions, kQTPropertyClass_ICMCompressionSessionOptions,
						kICMCompressionSessionOptionsPropertyID_MultiPassStorage, sizeof(ICMMultiPassStorageRef), &multiPassStorage );

 bail:
    if( noErr != status ) {
        // this api is NULL safe so we can just call it
        ICMMultiPassStorageRelease( multiPassStorage );
    }
	else {
        *outMultiPassStorage = multiPassStorage;
    }

    return status;
	*/
	
	OSStatus result;
	return result;
}

}

void MovieWriter::createCompressionSession()
{
	/* RE-IMPLEMENT
	OSStatus err = noErr;
	::ICMEncodedFrameOutputRecord encodedFrameOutputRecord = {0};
	::ICMCompressionSessionOptionsRef sessionOptions = NULL;
	::ICMMultiPassStorageRef multiPassStorage = 0;
	bool attemptMultiPass = mFormat.mEnableMultiPass;
	
	err = ::ICMCompressionSessionOptionsCreateCopy( NULL, mFormat.mOptions, &sessionOptions );
	if( err )
		goto bail;
	
	// We need durations when we store frames.
	err = ::ICMCompressionSessionOptionsSetDurationsNeeded( sessionOptions, true );
	if( err )
		goto bail;

	// if this codec definitely cannot do multipass, let's disable it
	::CodecInfo cInfo;
	::GetCodecInfo( &cInfo, mFormat.mCodec, 0 );

	//if( ! (cInfo.compressFlags & codecInfoDoesMultiPass) )
	//	attemptMultiPass = false;

	// if we have not enabled multiPass then explicitly disable it
	if( ! attemptMultiPass ) {
		::ICMMultiPassStorageRef nullStorage = NULL;
		::ICMCompressionSessionOptionsSetProperty( sessionOptions, kQTPropertyClass_ICMCompressionSessionOptions, 
													kICMCompressionSessionOptionsPropertyID_MultiPassStorage, 
													sizeof(ICMMultiPassStorageRef), 
													&nullStorage );
		mRequestedMultiPass = false;
	}
	else {
		err = enableMultiPassWithTemporaryFile( sessionOptions, &multiPassStorage );
		if( err ) 
			goto bail;
		mRequestedMultiPass = true;
	}
	
	encodedFrameOutputRecord.encodedFrameOutputCallback = encodedFrameOutputCallback;
	encodedFrameOutputRecord.encodedFrameOutputRefCon = this;
	encodedFrameOutputRecord.frameDataAllocator = NULL;
	err = ::ICMCompressionSessionCreate( NULL, mWidth, mHeight, mFormat.mCodec, mFormat.mTimeBase,
			sessionOptions, NULL, &encodedFrameOutputRecord, &mCompressionSession );
	if( err )
		goto bail;

	if( mRequestedMultiPass ) {
		mDoingMultiPass = ::ICMCompressionSessionSupportsMultiPassEncoding( mCompressionSession, 0, &mMultiPassModeFlags ) != 0;
		
		if( mDoingMultiPass ) {
			mMultiPassFrameCache = readWriteFileStream( getTemporaryFilePath() );
			if( ! mMultiPassFrameCache )
				throw MovieWriterExc();
			mMultiPassFrameCache->setDeleteOnDestroy();
		}

		// we have to do call this and its counterpart regardless, if \a mRequestedMultiPass
		::ICMCompressionSessionBeginPass( mCompressionSession, mMultiPassModeFlags, 0 );
		// the session has retained this so we can release it
		::ICMMultiPassStorageRelease( multiPassStorage );
	}
	else
		mDoingMultiPass = false;

	::ICMCompressionSessionOptionsRelease( sessionOptions );
	return;

bail:
	if( sessionOptions )
		::ICMCompressionSessionOptionsRelease( sessionOptions );
	throw MovieWriterExc();
	*/
	
}

namespace {
extern "C" void destroyDataArrayU8( void *releaseRefCon, const void *baseAddress )
{
	delete [] (reinterpret_cast<uint8_t*>( const_cast<void*>( baseAddress ) ));
}
} // anonymous namespace

void MovieWriter::finish()
{
	if( mFinished )
		return;

	/* RE-IMPLEMENT
	::ICMCompressionSessionCompleteFrames( mCompressionSession, true, 0, 0 );

	mFinished = true; // set this in case of throw, otherwise we could loop forever

	if( mDoingMultiPass ) {
		bool done = false;
		while( ! done ) {
			::ICMCompressionSessionEndPass( mCompressionSession );
			if( mMultiPassModeFlags & kICMCompressionPassMode_OutputEncodedFrames ) {
				done = true;
			}
			else {
				Boolean interpassDone = false;
				while( ! interpassDone ) {
					// passModeFlags will be set to the sessions recommended mode flags
					// for the next pass. kICMCompressionPassMode_OutputEncodedFrames will
					// only be set if the codec recommends that the next pass be the last
					::ICMCompressionSessionProcessBetweenPasses( mCompressionSession, 0, &interpassDone, &mMultiPassModeFlags );
				}
			}

			if( ! done ) { // do another pass
				::ICMCompressionSessionBeginPass( mCompressionSession, mMultiPassModeFlags, 0 );
				mMultiPassFrameCache->seekAbsolute( 0 );
				for( uint32_t frame = 0; frame < mNumFrames; ++frame ) {
					if( (mMultiPassModeFlags & kICMCompressionPassMode_NoSourceFrames) == 0 ) {
						::CVPixelBufferRef pixelBuffer;
						uint32_t width, height, format, rowBytes, dataSize;
						
						mMultiPassFrameCache->read( &width );
						mMultiPassFrameCache->read( &height );
						mMultiPassFrameCache->read( &format );
						mMultiPassFrameCache->read( &rowBytes );
						mMultiPassFrameCache->read( &dataSize );
						// this should probably be optimized with a pool eventually
						uint8_t *pixelData = new uint8_t[dataSize];
						mMultiPassFrameCache->readData( pixelData, dataSize );

						OSStatus err = ::CVPixelBufferCreateWithBytes( kCFAllocatorDefault, width, height, (OSType)format, pixelData, rowBytes, destroyDataArrayU8, NULL, NULL, &pixelBuffer );
						if( err != noErr )
							throw MovieWriterExcFrameEncode();

						::CFNumberRef gammaLevel = CFNumberCreate( kCFAllocatorDefault, kCFNumberFloatType, &mFormat.mGamma );
						::CVBufferSetAttachment( pixelBuffer, kCVImageBufferGammaLevelKey, gammaLevel, kCVAttachmentMode_ShouldPropagate );
						::CFRelease( gammaLevel );
						::CVBufferSetAttachment( pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate );

						::ICMValidTimeFlags validTimeFlags = kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid;
						::ICMCompressionFrameOptionsRef frameOptions = NULL;
						err = ::ICMCompressionSessionEncodeFrame( mCompressionSession, pixelBuffer, mFrameTimes[frame].first,
																		mFrameTimes[frame].second, validTimeFlags, frameOptions, NULL, NULL );
						::CVPixelBufferRelease( pixelBuffer );
					}
					else {
						::ICMValidTimeFlags validTimeFlags = kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid;
						::ICMCompressionFrameOptionsRef frameOptions = NULL;
						OSStatus err = ::ICMCompressionSessionEncodeFrame( mCompressionSession, NULL, mFrameTimes[frame].first,
																		mFrameTimes[frame].second, validTimeFlags, frameOptions, NULL, NULL );
					}
				}
				::ICMCompressionSessionCompleteFrames( mCompressionSession, true, 0, 0 );
			}
		}
	}
	else if( mRequestedMultiPass ) {
		::ICMCompressionSessionEndPass( mCompressionSession );
	}

	OSErr err;
	if( mMedia )  {
		err = ::EndMediaEdits( mMedia );
		if( err )
			throw MovieWriterExc();
            
		err = ::ExtendMediaDecodeDurationToDisplayEndTime( mMedia, NULL );
		if( err )
			throw MovieWriterExc();
            
		//Add media to track
		err = ::InsertMediaIntoTrack( mTrack, 0, 0, (TimeValue)::GetMediaDisplayDuration( mMedia ), fixed1 );
		if( err )
			throw MovieWriterExc();
            
		//Write movie
		err = ::AddMovieToStorage( mMovie, mDataHandler );
		if( err )
			throw MovieWriterExc();
	}
        
	// Close movie file
	if( mDataHandler )
		::CloseMovieStorage( mDataHandler );

	if( mMovie )
		::DisposeMovie( mMovie );
		*/

	NSError* error = nil;
	bool success = [mWriter finishWriting];
	if (!success)
		error = [mWriter error];
}

bool MovieWriter::getUserCompressionSettings( Format* result, ImageSourceRef imageSource )
{
	
	/* RE-IMPLEMENT
	ComponentInstance stdCompression = 0;
	long scPreferences;
	ICMCompressionSessionOptionsRef sessionOptionsRef = NULL;
	ComponentResult err;

	startQuickTime();

	err = ::OpenADefaultComponent( ::StandardCompressionType, ::StandardCompressionSubType, &stdCompression );
	if( err || ( stdCompression == 0 ) )
		return false;

	// Indicates the client is ready to use the ICM compression session API to perform compression operations
	// StdCompression will disable frame reordering and multi pass encoding if this flag not set because the
	// older sequence APIs do not support these capabilities
	scPreferences = scAllowEncodingWithCompressionSession;

	// set the preferences we want
	err = ::SCSetInfo( stdCompression, ::scPreferenceFlagsType, &scPreferences );
	if( err ) {
	    if( stdCompression )
			::CloseComponent( stdCompression );
		return false;
	}

	// display the standard compression dialog box
	err = ::SCRequestSequenceSettings( stdCompression );

	// now process the result
	if( err ) {
	    if( stdCompression )
			::CloseComponent( stdCompression );
		return false;
	}

	// pull out the codec and quality
	::SCSpatialSettings spatialSettings;
	::SCGetInfo( stdCompression, scSpatialSettingsType, &spatialSettings );
	::CodecType codec = spatialSettings.codecType;
	::CodecQ quality = spatialSettings.spatialQuality;

	::SCTemporalSettings temporalSettings;
	::SCGetInfo( stdCompression, scTemporalSettingsType, &temporalSettings );

	::SCVideoMultiPassEncodingSettings multiPassSettings;
	::SCGetInfo( stdCompression, scVideoMultiPassEncodingSettingsType, &multiPassSettings );

	// creates a compression session options object based on configured settings
	err = ::SCCopyCompressionSessionOptions( stdCompression, &sessionOptionsRef );
    if( stdCompression )
		::CloseComponent( stdCompression );

	*result = Format( sessionOptionsRef, static_cast<uint32_t>( codec ), quality / (float)codecLosslessQuality,
						FixedToFloat( temporalSettings.frameRate ), multiPassSettings.allowMultiPassEncoding != 0 );

	return true;
	*/
	
	return false;
}

} } // namespace cinder::avf