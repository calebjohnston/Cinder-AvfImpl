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
	
	void playerReady();
	
	bool mMovieSelected;
	ci::gl::Texture mTexture;
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
	mMovieSelected = false;

	if (true) {
		fs::path asset_path = getResourcePath("assets/Prometheus.mov");
		mMovie = avf::MovieSurface::create(asset_path);
		mMovie->getReadySignal().connect(std::bind(&IosApp::playerReady, this));
	}
	else {
		Url url("http://www.calebjohnston.com/storage/windtunnel_vectors_02w.mov");
		mMovieLoader = avf::MovieLoader::create(url);
		mMovie = avf::MovieSurface::create(mMovieLoader);
	}
}

void IosApp::playerReady()
{
	mMovieSelected = true;
	mMovie->setVolume(1.0f);
	mMovie->play();
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
		//mTexture = mMovie->getTexture();
		mTexture = gl::Texture(mMovie->getSurface());
	}
	else if (mMovie->checkPlayThroughOk()) {
		mMovie->play();
		mMovieSelected = true;
	}
}

void IosApp::draw()
{
	// clear out the window with black
	gl::clear( ColorA::black() );
	
	if (!mMovieSelected) return;
	
	if (mTexture) {
		Rectf bounds = getWindowBounds();
		Rectf centeredRect = Rectf( mTexture.getBounds() ).getCenteredFit( bounds, true );
		gl::draw(mTexture, centeredRect);
	}
}

CINDER_APP_NATIVE( IosApp, RendererGl )
