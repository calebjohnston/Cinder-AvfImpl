#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class CaptureApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void CaptureApp::setup()
{
}

void CaptureApp::mouseDown( MouseEvent event )
{
}

void CaptureApp::update()
{
}

void CaptureApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( CaptureApp, RendererGl )
