#include "cinder/app/AppNative.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/gl.h"

#include "Avf.h"

class MacApp : public ci::app::AppNative {
  public:
	void setup();
	void keyDown( ci::app::KeyEvent event );
	void keyUp( ci::app::KeyEvent event );
	void mouseDown( ci::app::MouseEvent event );
	void mouseUp( ci::app::MouseEvent event );
	void update();
	void draw();
	
	void newMovieFrame();
	void movieEnded();
	void playerReady();
	
	bool mMovieSelected;
	uint32_t mFrameCount;
	uint32_t mMovieFrameCount;
	ci::gl::Texture mTexture;
	ci::Surface mSurface;
	ci::avf::MovieGlRef mMovie;
//	ci::avf::MovieSurfaceRef mMovie;
	ci::avf::MovieLoaderRef mMovieLoader;
};

using namespace ci;
using namespace ci::app;
using namespace std;

void MacApp::setup()
{
	mMovieFrameCount = mFrameCount = 0;
	mMovieSelected = false;
	
	setFrameRate(60);
	
#if defined( CINDER_MAC )
	
	if (true) {
		fs::path movie_path = getOpenFilePath();
		if( !movie_path.empty() ) {
			mMovie = avf::MovieGl::create(movie_path);
//			mMovie = avf::MovieSurface::create(movie_path);
			mMovieSelected = true;
		}
	}
	else if (false) {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_new-solver02.mov");
		mMovie = avf::MovieGl::create(url);
//		mMovie = avf::MovieSurface::create(url);
		mMovieSelected = true;
	}
	else {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//mMovieLoader = avf::MovieLoader::create(url);
		mMovieLoader = avf::MovieLoader::create(url);
		mMovie = avf::MovieGl::create(mMovieLoader);
//		mMovie = avf::MovieSurface::create(*mMovieLoader);
		mMovieSelected = true;
	}
	
	//mPlayer->load(Url("/Users/Caleb/Movies/Ford_Intro.mov"));
	//mPlayer->load(Url("/Users/Caleb/Movies/bottom.mov"));
	
#else
	//	fs::path app_path = cinder::app::App::getAppPath();
	mMovieSelected = true;
	fs::path asset_path = getResourcePath("assets");
	fs::path url_path = getResourcePath("assets/Ford_Intro.mov");
	mMovie = avf::MovieGl::create(Url(url_path.string()));
	
#endif
	
	if (mMovieSelected) {
		mMovie->getReadySignal().connect(boost::bind(&MacApp::playerReady, this));
		mMovie->getNewFrameSignal().connect(boost::bind(&MacApp::newMovieFrame, this));
		mMovie->getEndedSignal().connect(boost::bind(&MacApp::movieEnded, this));
	}
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
}

void MacApp::movieEnded()
{
	console() << "measured total number of frames = " << mMovieFrameCount << std::endl;
	
	mMovieSelected = false;
	
	fs::path movie_path = getOpenFilePath();
	if( !movie_path.empty() ) {
		mMovie = avf::MovieGl::create(movie_path);
		mMovie->getEndedSignal().connect(boost::bind(&MacApp::movieEnded, this));
		mMovie->play();
		
		mMovieSelected = true;
	}
}

void MacApp::newMovieFrame()
{
	mMovieFrameCount++;
}

void MacApp::update()
{
	if (mMovieSelected) {
		mTexture = mMovie->getTexture();
//		mSurface = mMovie->getSurface();
//		if (mSurface) mTexture = gl::Texture(mSurface);
	}
}

void MacApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		//gl::color(0.1,0.1,0.1,0.1);
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
	
	if (mFrameCount >= 30) {
		mFrameCount = 0;
		int fps = static_cast<int>(getAverageFps());
		//console() << "fps: " << fps << std::endl;
	}
	else {
		mFrameCount++;
	}
}

CINDER_APP_NATIVE( MacApp, RendererGl )
