#include "cinder/app/AppNative.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/gl.h"

#include "Avf.h"

class MovieLoaderTestApp : public ci::app::AppNative {
  public:
	void setup();
	void keyDown( ci::app::KeyEvent event );
	void keyUp( ci::app::KeyEvent event );
	void mouseDown( ci::app::MouseEvent event );
	void mouseUp( ci::app::MouseEvent event );
	void update();
	void draw();
	
	bool mMovieSelected;
	ci::gl::Texture mTexture;
	ci::avf::MovieGlRef mMovie;
	ci::avf::MovieLoaderRef mMovieLoader;
};

using namespace ci;
using namespace ci::app;
using namespace std;

void MovieLoaderTestApp::setup()
{
	mMovieSelected = false;
	
	setFrameRate(60);
	
#if defined( CINDER_MAC )
	
	Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
	//Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
	mMovieLoader = avf::MovieLoader::create(url);
	mMovie = avf::MovieGl::create(mMovieLoader);
	mMovieSelected = true;
	
#else
	//	fs::path app_path = cinder::app::App::getAppPath();
	Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
	mMovieLoader = avf::MovieLoader::create(url);
	mMovie = avf::MovieGl::create(mMovieLoader);
	mMovieSelected = true;
	
#endif
	
}

void MovieLoaderTestApp::keyDown( KeyEvent event )
{
	switch(event.getChar()) {
		case 'p':
			mMovie->play(true);
			break;
		case 's': mMovie->seekToStart();
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

void MovieLoaderTestApp::keyUp( KeyEvent event )
{
}

void MovieLoaderTestApp::mouseDown( MouseEvent event )
{
}

void MovieLoaderTestApp::mouseUp( MouseEvent event )
{
}

void MovieLoaderTestApp::update()
{
	if (mMovieSelected) {
		mTexture = mMovie->getTexture();
	}
}

void MovieLoaderTestApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
}

CINDER_APP_NATIVE( MovieLoaderTestApp, RendererGl )
