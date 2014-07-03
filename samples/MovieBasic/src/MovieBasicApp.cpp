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
	
	void keyDown( KeyEvent event );
	void mouseDown( MouseEvent event );
	void mouseUp( MouseEvent event );
	void fileDrop( FileDropEvent event );
	
	void update();
	void draw();
	
  private:
	void movieReady();
	void loadMovieFile( const fs::path &path );
	
	gl::Texture		mFrameTexture, mInfoTexture;
	avf::MovieGlRef	mMovie;
	fs::path		mMoviePath;
};

void MovieBasicApp::setup()
{
	fs::path moviePath = getOpenFilePath();
	if( ! moviePath.empty() )
		loadMovieFile( moviePath );
}

void MovieBasicApp::keyDown( KeyEvent event )
{
	if( event.getChar() == 'f' )
		setFullScreen( !isFullScreen() );
	else if( event.getChar() == 'o' ) {
		fs::path moviePath = getOpenFilePath();
		if( ! moviePath.empty() )
			loadMovieFile( moviePath );
	}
	else if( event.getChar() == '1' )
		mMovie->setRate( 0.5f );
	else if( event.getChar() == '2' )
		mMovie->setRate( 1 );
	else if( event.getChar() == '3' )
		mMovie->setRate( 2 );
}

void MovieBasicApp::mouseDown( MouseEvent event )
{
	if( mMovie )
		mMovie->play( true );
}

void MovieBasicApp::mouseUp( MouseEvent event )
{
}

void MovieBasicApp::fileDrop( FileDropEvent event )
{
	loadMovieFile( event.getFile( 0 ) );
}

void MovieBasicApp::update()
{
	if( mMovie )
		mFrameTexture = mMovie->getTexture();
}

void MovieBasicApp::draw()
{    
	gl::clear();
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

void MovieBasicApp::movieReady()
{
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

void MovieBasicApp::loadMovieFile( const fs::path& moviePath )
{
	try {
		mMoviePath = moviePath;
		// load up the movie, set it to loop, and begin playing
		mMovie = avf::MovieGl::create( mMoviePath );
		mMovie->setLoop();
		mMovie->getReadySignal().connect(std::bind(&MovieBasicApp::movieReady, this));
	}
	catch( ... ) {
		console() << "Unable to load the movie." << std::endl;
		//mMovie->reset();
		mInfoTexture.reset();
	}
	
	mFrameTexture.reset();
}

CINDER_APP_NATIVE( MovieBasicApp, RendererGl )
