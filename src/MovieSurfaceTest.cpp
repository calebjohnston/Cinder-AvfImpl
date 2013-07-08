#include "cinder/app/AppNative.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/gl.h"

#include "Avf.h"

class MovieSurfaceTestApp : public ci::app::AppNative {
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
	ci::Surface mSurface;
	ci::gl::Texture mTexture;
	ci::avf::MovieSurfaceRef mMovie;
};

using namespace ci;
using namespace ci::app;
using namespace std;

void MovieSurfaceTestApp::setup()
{
	mMovieSelected = false;
	
	setFrameRate(60);
	
#if defined( CINDER_MAC )
	
	if (false) {
		fs::path movie_path = getOpenFilePath();
		if( !movie_path.empty() ) {
			mMovie = avf::MovieSurface::create(movie_path);
			mMovieSelected = true;
		}
	}
	else if (false) {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_new-solver02.mov");
		mMovie = avf::MovieSurface::create(url);
		mMovieSelected = true;
	}
	
#else
	//	fs::path app_path = cinder::app::App::getAppPath();
	mMovieSelected = true;
	fs::path asset_path = getResourcePath("assets");
	fs::path url_path = getResourcePath("assets/Ford_Intro.mov");
	mMovie = avf::MovieGl::create(Url(url_path.string()));
	
#endif
	
	if (mMovieSelected) {
		mMovie->getReadySignal().connect(boost::bind(&MovieSurfaceTestApp::playerReady, this));
		mMovie->getNewFrameSignal().connect(boost::bind(&MovieSurfaceTestApp::newMovieFrame, this));
		mMovie->getEndedSignal().connect(boost::bind(&MovieSurfaceTestApp::movieEnded, this));
	}
}

void MovieSurfaceTestApp::keyDown( KeyEvent event )
{
	switch(event.getChar()) {
		case 'p': mMovie->play(true);
			break;
		case 's': mMovie->setActiveSegment(10.0f, 10.0f);
			break;
		case 'e': mMovie->seekToEnd();
			break;
		case 'r': mMovie->resetActiveSegment();
			break;
	}
}

void MovieSurfaceTestApp::keyUp( KeyEvent event )
{
}

void MovieSurfaceTestApp::mouseDown( MouseEvent event )
{
}

void MovieSurfaceTestApp::mouseUp( MouseEvent event )
{
}

void MovieSurfaceTestApp::playerReady()
{
	ci::app::console() << "MovieSurfaceTestApp::playerReady " << std::endl;
}

void MovieSurfaceTestApp::movieEnded()
{
	ci::app::console() << "MovieSurfaceTestApp::movieEnded " << std::endl;
}

void MovieSurfaceTestApp::newMovieFrame()
{
}

void MovieSurfaceTestApp::update()
{
	if (mMovieSelected) {
		mSurface = mMovie->getSurface();
		if (mSurface) mTexture = gl::Texture(mSurface);
	}
}

void MovieSurfaceTestApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
}

CINDER_APP_NATIVE( MovieSurfaceTestApp, RendererGl )
