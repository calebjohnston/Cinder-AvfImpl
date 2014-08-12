#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Utilities.h"
#include "cinder/Text.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieBasicApp : public AppNative {
  public:
	void setup();
	
	void touchesBegan( TouchEvent event );
	
	void update();
	void draw();

  private:
    void onReadySignal();
	
	gl::Texture		mFrameTexture, mInfoTexture;
	avf::MovieSurfaceRef mMovie;
	fs::path		mMoviePath;
};

void MovieBasicApp::setup()
{
    fs::path moviePath = getResourcePath("windtunnel_vectors_02w.mov");
    mMovie = avf::MovieSurface::create(moviePath);

    if( mMovie ) {
        mMoviePath = moviePath;
        mMovie->getReadySignal().connect(std::bind(&MovieBasicApp::onReadySignal, this));
    }
}

void MovieBasicApp::onReadySignal()
{    
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

	mMovie->setVolume(1.0f);
	mMovie->play();
}

void MovieBasicApp::touchesBegan( TouchEvent event )
{
	if( mMovie )
		mMovie->play( true );
}

void MovieBasicApp::update()
{
	if( mMovie ) {
        ci::Surface surface = mMovie->getSurface();
        if(surface) mFrameTexture = gl::Texture(mMovie->getSurface());
    }
}

void MovieBasicApp::draw()
{
	// clear out the window with black
	gl::clear( ColorA::black() );
	gl::enableAlphaBlending();
	
	if( mFrameTexture ) {
		Rectf centeredRect = Rectf( mFrameTexture.getBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::draw( mFrameTexture, centeredRect  );
	}
	
	if( mInfoTexture ) {
        // error
        //		glDisable( GL_TEXTURE_RECTANGLE_ARB );
		gl::draw( mInfoTexture, Vec2f( 20, getWindowHeight() - 20 - mInfoTexture.getHeight() ) );
	}
}

CINDER_APP_NATIVE( MovieBasicApp, RendererGl )