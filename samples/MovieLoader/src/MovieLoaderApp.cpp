#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieLoaderApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void MovieLoaderApp::setup()
{
}

void MovieLoaderApp::mouseDown( MouseEvent event )
{
}

void MovieLoaderApp::update()
{
}

void MovieLoaderApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( MovieLoaderApp, RendererGl )
