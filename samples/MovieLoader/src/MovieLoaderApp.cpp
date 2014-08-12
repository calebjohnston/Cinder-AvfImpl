#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieLoaderApp : public AppNative {
  public:
	void setup();

	void update();
	void draw();
	
  private:
	void movieReady();
	
	avf::MovieGlRef	mMovie;
	avf::MovieLoaderRef mLoader;
};

void MovieLoaderApp::setup()
{
	Url url("http://pdl.warnerbros.com/wbol/us/dd/med/northbynorthwest/quicktime_page/nbnf_airplane_explosion_qt_500.mov");
	mLoader = avf::MovieLoader::create(url);
	mMovie = avf::MovieGl::create(mLoader);
}

void MovieLoaderApp::update()
{
	if( mLoader && !mMovie->isPlaying() && mLoader->checkPlayThroughOk()) {
		movieReady();
	}
}

void MovieLoaderApp::draw()
{
	// clear out the window with black
	gl::clear(); 
}

void MovieLoaderApp::movieReady()
{
	mMovie->play();
}

CINDER_APP_NATIVE( MovieLoaderApp, RendererGl )