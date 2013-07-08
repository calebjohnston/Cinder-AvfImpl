#include "cinder/app/AppNative.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/gl.h"

#include "Avf.h"

class MovieGlTestApp : public ci::app::AppNative {
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
	ci::gl::Texture mTexture;
	ci::avf::MovieGlRef mMovie;
};

using namespace ci;
using namespace ci::app;
using namespace std;

void MovieGlTestApp::setup()
{
	mMovieSelected = false;
	
	setFrameRate(60);
	
#if defined( CINDER_MAC )
	
	if (false) {
		fs::path movie_path = getOpenFilePath();
		if( !movie_path.empty() ) {
			mMovie = avf::MovieGl::create(movie_path);
			mMovieSelected = true;
		}
	}
	else if (false) {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		//Url url("http://www.calebjohnston.com/storage/windtunnel_new-solver02.mov");
		mMovie = avf::MovieGl::create(url);
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
		mMovie->getReadySignal().connect(boost::bind(&MovieGlTestApp::playerReady, this));
		mMovie->getNewFrameSignal().connect(boost::bind(&MovieGlTestApp::newMovieFrame, this));
		mMovie->getEndedSignal().connect(boost::bind(&MovieGlTestApp::movieEnded, this));
	}
}

void MovieGlTestApp::keyDown( KeyEvent event )
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

void MovieGlTestApp::keyUp( KeyEvent event )
{
}

void MovieGlTestApp::mouseDown( MouseEvent event )
{
}

void MovieGlTestApp::mouseUp( MouseEvent event )
{
}

void MovieGlTestApp::playerReady()
{
	ci::app::console() << "MovieGlTestApp::playerReady " << std::endl;
}

void MovieGlTestApp::movieEnded()
{
	ci::app::console() << "MovieGlTestApp::movieEnded " << std::endl;
}

void MovieGlTestApp::newMovieFrame()
{
}

void MovieGlTestApp::update()
{
	if (mMovieSelected) {
		mTexture = mMovie->getTexture();
	}
}

void MovieGlTestApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
}

CINDER_APP_NATIVE( MovieGlTestApp, RendererGl )
