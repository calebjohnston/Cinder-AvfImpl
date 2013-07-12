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
	void mouseDown( MouseEvent event );
	void update();
	void draw();
	
  private:
	void movieReady();
	
	gl::Texture mFrameTexture, mInfoTexture;
	avf::MovieGlRef	mMovie;
	avf::MovieLoaderRef mLoader;
};

void MovieLoaderApp::setup()
{
	Url url("http://pdl.warnerbros.com/wbol/us/dd/med/northbynorthwest/quicktime_page/nbnf_airplane_explosion_qt_500.mov");
	mLoader = avf::MovieLoader::create(url);
	mMovie = avf::MovieGl::create(mLoader);
}

void MovieLoaderApp::mouseDown( MouseEvent event )
{
}

void MovieLoaderApp::update()
{
	if( mLoader && !mMovie->isPlaying() && mLoader->checkPlayThroughOk()){
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
	
	// create a texture for showing some info about the movie
	TextLayout infoText;
	infoText.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
	infoText.setColor( Color::white() );
	infoText.addLine( toString( mMovie->getWidth() ) + " x " + toString( mMovie->getHeight() ) + " pixels" );
	infoText.addLine( toString( mMovie->getDuration() ) + " seconds" );
	infoText.addLine( toString( mMovie->getNumFrames() ) + " frames" );
	infoText.addLine( toString( mMovie->getFramerate() ) + " fps" );
	infoText.setBorder( 4, 2 );
	mInfoTexture = gl::Texture( infoText.render( true ) );
}

CINDER_APP_NATIVE( MovieLoaderApp, RendererGl )
