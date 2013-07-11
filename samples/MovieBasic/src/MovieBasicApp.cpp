#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieBasicApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void MovieBasicApp::setup()
{
}

void MovieBasicApp::mouseDown( MouseEvent event )
{
}

void MovieBasicApp::update()
{
}

void MovieBasicApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( MovieBasicApp, RendererGl )
