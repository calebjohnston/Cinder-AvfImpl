#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

#include "Avf.h"
#include "AvfUtils.h"

class IosApp : public ci::app::AppNative {
public:
	void prepareSettings( ci::app::App::Settings* settings );
	void setup();
    
	void touchesBegan( ci::app::TouchEvent event );
	void touchesEnded( ci::app::TouchEvent event );
	
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
	ci::avf::MovieSurfaceRef mMovie;
	ci::avf::MovieLoaderRef mMovieLoader;
};

using namespace ci;
using namespace ci::app;
using namespace std;

void IosApp::prepareSettings( App::Settings* settings )
{
}

void IosApp::setup()
{
    mMovieFrameCount = mFrameCount = 0;
	mMovieSelected = false;

	if (true) {
		fs::path movie_path = getResourcePath("windtunnel_vectors_02w.mov");
        mMovie = avf::MovieSurface::create(movie_path);
        mMovieSelected = true;
	}
	else {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		mMovieLoader = avf::MovieLoader::create(url);
		mMovie = avf::MovieSurface::create(mMovieLoader);
        mMovieSelected = true;
	}
    
    if(mMovieSelected) {
        mMovie->getReadySignal().connect(std::bind(&IosApp::playerReady, this));
        mMovie->getNewFrameSignal().connect(std::bind(&IosApp::newMovieFrame, this));
        mMovie->getEndedSignal().connect(std::bind(&IosApp::movieEnded, this));
    }
}

void IosApp::playerReady()
{
    ci::app::console() << "IosApp::playerReady ---------------- " << std::endl;
	mMovie->setVolume(1.0f);
	mMovie->play();
}

void IosApp::movieEnded()
{
	console() << "measured total number of frames = " << mMovieFrameCount << std::endl;
	
	mMovieSelected = false;
}

void IosApp::newMovieFrame()
{
	mMovieFrameCount++;
}

void IosApp::touchesBegan( TouchEvent event )
{
	mMovie->setVolume(0.25f);
}

void IosApp::touchesEnded( TouchEvent event )
{
}

void IosApp::update()
{
	if (mMovieSelected) {
        ci::Surface surface = mMovie->getSurface();
        if(surface) mTexture = gl::Texture(surface);
	}
}

void IosApp::draw()
{
	// clear out the window with black
	gl::clear( ColorA::black() );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw(mTexture, centeredRect);
	}
    
    if (mFrameCount >= 30) {
		mFrameCount = 0;
	}
	else {
		mFrameCount++;
	}
}

CINDER_APP_NATIVE( IosApp, RendererGl )
