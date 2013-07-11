#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieWriterApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void MovieWriterApp::setup()
{
}

void MovieWriterApp::mouseDown( MouseEvent event )
{
}

void MovieWriterApp::update()
{
}

void MovieWriterApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( MovieWriterApp, RendererGl )
