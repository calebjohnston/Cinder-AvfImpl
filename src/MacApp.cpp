#include "cinder/app/AppNative.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/gl.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MacApp : public ci::app::AppNative {
  public:
	void setup();
    void prepareSettings( ci::app::AppBasic::Settings *settings );
	void keyDown( ci::app::KeyEvent event );
	void keyUp( ci::app::KeyEvent event );
	void mouseDown( ci::app::MouseEvent event );
	void mouseUp( ci::app::MouseEvent event );
	void update();
	void draw();
	
	void newMovieFrame();
	void movieEnded();
	void playerReady();
	
	uint32_t mFrameCount;
	uint32_t mMovieFrameCount;
	ci::gl::Texture mTexture, mInfoTexture;
	ci::Surface mSurface;
	ci::avf::MovieGlRef mMovie;
	ci::avf::MovieLoaderRef mMovieLoader;
    fs::path mMoviePath;
};

void MacApp::prepareSettings(ci::app::AppBasic::Settings *settings) {
    settings->setWindowSize(3840/2, 2160/2); // for 4k videos
}

void MacApp::setup()
{
	mMovieFrameCount = mFrameCount = 0;
	
	setFrameRate(60);
	
#if defined( CINDER_MAC )
	
	if (true) {
		fs::path movie_path = getOpenFilePath();
		if( !movie_path.empty() ) {
            mMoviePath = movie_path;
			mMovie = avf::MovieGl::create(movie_path);
		}
	}
	else if (false) {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_new-solver02.mov");
		mMovie = avf::MovieGl::create(url);
	}
	else {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		mMovieLoader = avf::MovieLoader::create(url);
		mMovie = avf::MovieGl::create(mMovieLoader);
	}
	
	//mPlayer->load(Url("/Users/Caleb/Movies/Ford_Intro.mov"));
	//mPlayer->load(Url("/Users/Caleb/Movies/bottom.mov"));
	
#else
	//	fs::path app_path = cinder::app::App::getAppPath();
	fs::path asset_path = getResourcePath("assets");
	fs::path url_path = getResourcePath("assets/Ford_Intro.mov");
	mMovie = avf::MovieGl::create(Url(url_path.string()));
	
#endif
	
	if (mMovie) {
		mMovie->getReadySignal().connect(boost::bind(&MacApp::playerReady, this));
		mMovie->getNewFrameSignal().connect(boost::bind(&MacApp::newMovieFrame, this));
		mMovie->getEndedSignal().connect(boost::bind(&MacApp::movieEnded, this));
	}
    
    ci::app::console() << "MacApp::setup -------- " << std::endl;
}

void MacApp::keyDown( KeyEvent event )
{
	switch(event.getChar()) {
		case 'p':
			//mMovie->setActiveSegment(10.0f, 10.0f);
			mMovie->play(true);
			break;
		case 's': mMovie->seekToStart();
			break;
		case 'g':
			ci::app::console() << "aspect? " << mMovie->getPixelAspectRatio() << std::endl;
			break;
		case 'e': mMovie->seekToEnd();
			break;
		case 'v': mMovie->getVolume();
			break;
		case 'r':
			mMovie->resetActiveSegment();
			break;
			
		case 'c':
			ci::app::console() << "protected? " << mMovieLoader->checkProtection() << std::endl;
			break;
		case 'l':
			mMovieLoader->waitForLoaded();
			break;
		case 'o':
			ci::app::console() << mMovieLoader->checkPlayThroughOk() << std::endl;
			break;
			
		case 'w':
			mMovieLoader->waitForPlayThroughOk();
			ci::app::console() << "1 play though ok! " << std::endl;
			break;
		case 'q':
			bool check = mMovieLoader->checkPlayThroughOk();
			ci::app::console() << "2 play though ok? " << check << std::endl;
			break;
	}
}

void MacApp::keyUp( KeyEvent event )
{
}

void MacApp::mouseDown( MouseEvent event )
{
}

void MacApp::mouseUp( MouseEvent event )
{
}

void MacApp::playerReady()
{
	ci::app::console() << "MacApp::playerReady " << std::endl;
	mMovie->setVolume(1.0f);
	mMovie->play();
    
	// create a texture for showing some info about the movie
	TextLayout infoText;
	infoText.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
	infoText.setColor( Color::white() );
	infoText.addCenteredLine( mMoviePath.filename().string() );
	infoText.addLine( toString( mMovie->getWidth() ) + " x " + toString( mMovie->getHeight() ) + " pixels" );
	infoText.addLine( toString( mMovie->getDuration() ) + " seconds" );
	infoText.addLine( toString( mMovie->getNumFrames() ) + " frames" );
	infoText.addLine( toString( mMovie->getFramerate() ) + " fps" );
	infoText.setBorder( 4, 2 );
	mInfoTexture = gl::Texture( infoText.render( true ) );
}

void MacApp::movieEnded()
{
	console() << "measured total number of frames = " << mMovieFrameCount << std::endl;
		
	fs::path movie_path = getOpenFilePath();
	if( !movie_path.empty() ) {
		mMovie = avf::MovieGl::create(movie_path);
		mMovie->getEndedSignal().connect(boost::bind(&MacApp::movieEnded, this));
		mMovie->play();
    }
}

void MacApp::newMovieFrame()
{
	mMovieFrameCount++;
}

void MacApp::update()
{
	if (mMovie) {
		mTexture = mMovie->getTexture();
	}
}

void MacApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
	
	if (!mMovie) return;
	
	if (mTexture) {
		//gl::color(0.1,0.1,0.1,0.1);
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
	
	if (mFrameCount >= 30) {
		mFrameCount = 0;
	}
	else {
		mFrameCount++;
	}

    if( mInfoTexture ) {
		gl::draw( mInfoTexture, Vec2f( 20, getWindowHeight() - 20 - mInfoTexture.getHeight() ) );
	}
    
	// draw fps
	TextLayout infoFps;
	infoFps.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
	infoFps.setColor( Color::white() );
	infoFps.addLine( "Movie Framerate: " + toString( mMovie->getPlaybackFramerate()) );
	infoFps.addLine( "App Framerate: " + toString( this->getAverageFps()) );
	infoFps.setBorder( 4, 2 );
	gl::draw( gl::Texture( infoFps.render( true ) ), Vec2f( 20, 20 ) );
}

CINDER_APP_NATIVE( MacApp, RendererGl )
