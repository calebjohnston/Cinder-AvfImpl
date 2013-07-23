#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

#include "AvfWriter.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieWriterApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
	
	float mAngle;
	ci::avf::MovieWriterRef mMovieExporter;
};

void MovieWriterApp::setup()
{
	mAngle = 0;
	
	fs::path path = getSaveFilePath();
	if (!path.empty()) {
//		path += "Movie.mov";
		mMovieExporter = ci::avf::MovieWriter::create(path, getWindowWidth(), getWindowHeight());
	}
}

void MovieWriterApp::mouseDown( MouseEvent event )
{
}

void MovieWriterApp::update()
{
	if (mMovieExporter) mMovieExporter->addFrame(copyWindowSurface());
}

void MovieWriterApp::draw()
{
	gl::clear();
	gl::enableDepthRead();
	gl::pushModelView();
	gl::translate(getWindowWidth()/2.0f, getWindowHeight()/2.0f);
	gl::rotate(Vec3f(0,mAngle+=1.0f,0));
	gl::drawColorCube(Vec3f(0, 0, 0), Vec3f(150,150,150));
	gl::popModelView();
}

CINDER_APP_NATIVE( MovieWriterApp, RendererGl )
