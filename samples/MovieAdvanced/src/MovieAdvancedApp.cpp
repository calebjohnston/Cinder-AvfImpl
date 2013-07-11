#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieAdvancedApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void MovieAdvancedApp::setup()
{
}

void MovieAdvancedApp::mouseDown( MouseEvent event )
{
}

void MovieAdvancedApp::update()
{
}

void MovieAdvancedApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( MovieAdvancedApp, RendererGl )
