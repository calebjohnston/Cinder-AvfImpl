#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieAdvancedApp : public AppNative {
  public:
	void prepareSettings( Settings* settings );
	void setup();
	void keyDown( KeyEvent event );
	void fileDrop( FileDropEvent event );
	void mouseDown( MouseEvent event );
	void touchesBegan( TouchEvent event );
	
	void update();
	void draw();
	
  private:
	void addActiveMovie( avf::MovieGlRef movie );
	void loadMovieUrl( const std::string& urlString );
	void loadMovieFile( const fs::path& path );
	
	fs::path mLastPath;
	// all of the actively playing movies
	vector<avf::MovieGlRef> mMovies;
	// movies we're still waiting on to be loaded
	vector<avf::MovieLoaderRef> mLoadingMovies;
};

void MovieAdvancedApp::prepareSettings( Settings *settings )
{
	settings->setWindowSize( 800, 600 );
	settings->setFullScreen( false );
	settings->setResizable( true );
}

void MovieAdvancedApp::setup()
{
	srand( 133 );
	fs::path moviePath = getOpenFilePath();
	if( ! moviePath.empty() )
		loadMovieFile( moviePath );
}

void MovieAdvancedApp::mouseDown( MouseEvent event )
{
}

void MovieAdvancedApp::touchesBegan( TouchEvent event )
{
}

void MovieAdvancedApp::keyDown( KeyEvent event )
{
	if( event.getChar() == 'f' ) {
		setFullScreen( !isFullScreen() );
	}
	else if( event.getChar() == 'o' ) {
		fs::path moviePath = getOpenFilePath();
		if( ! moviePath.empty() )
			loadMovieFile( moviePath );
	}
	else if( event.getChar() == 'O' ) {
		if( ! mLastPath.empty() )
			loadMovieFile( mLastPath );
	}
	else if( event.getChar() == 'x' ) {
		mMovies.clear();
		mLoadingMovies.clear();
	}
	else if( event.getChar() == 'd' ) {
		if( ! mMovies.empty() )
			mMovies.erase( mMovies.begin() + ( rand() % mMovies.size() ) );
	}
	else if( event.getChar() == 'u' ) {
		vector<string> randomMovie;
		randomMovie.push_back( "http://movies.apple.com/movies/us/hd_gallery/gl1800/480p/bbc_earth_m480p.mov" );
		randomMovie.push_back( "http://movies.apple.com/media/us/quicktime/guide/hd/480p/noisettes_m480p.mov" );
		randomMovie.push_back( "http://pdl.warnerbros.com/wbol/us/dd/med/northbynorthwest/quicktime_page/nbnf_airplane_explosion_qt_500.mov" );
		loadMovieUrl( randomMovie[rand() % randomMovie.size()] );
	}
}

void MovieAdvancedApp::addActiveMovie( avf::MovieGlRef movie )
{
	console() << "Dimensions:" << movie->getWidth() << " x " << movie->getHeight() << std::endl;
	console() << "Duration:  " << movie->getDuration() << " seconds" << std::endl;
	console() << "Frames:    " << movie->getNumFrames() << std::endl;
	console() << "Framerate: " << movie->getFramerate() << std::endl;
	movie->setLoop( true, false );
	
	mMovies.push_back( movie );
	movie->play();
}

void MovieAdvancedApp::loadMovieUrl( const string& urlString )
{
	try {
		mLoadingMovies.push_back( avf::MovieLoader::create( Url( urlString ) ) );
	}
	catch( ... ) {
		console() << "Unable to load the movie from URL: " << urlString << std::endl;
	}
}

void MovieAdvancedApp::loadMovieFile( const fs::path& moviePath )
{
	avf::MovieGlRef movie;
	
	try {
		movie = avf::MovieGl::create( moviePath );
		
		addActiveMovie( movie );
		mLastPath = moviePath;
	}
	catch( ... ) {
		console() << "Unable to load the movie." << std::endl;
		return;
	}
}

void MovieAdvancedApp::fileDrop( FileDropEvent event )
{
	for( size_t s = 0; s < event.getNumFiles(); ++s )
		loadMovieFile( event.getFile( s ) );
}

void MovieAdvancedApp::update()
{
	// let's see if any of our loading movies have finished loading and can be made active
	for( vector<avf::MovieLoaderRef>::iterator loaderIt = mLoadingMovies.begin(); loaderIt != mLoadingMovies.end(); ) {
		try {
			if( (*loaderIt)->checkPlayThroughOk() ) {
				avf::MovieGlRef movie = avf::MovieGl::create( *loaderIt );
				addActiveMovie( movie );
				loaderIt = mLoadingMovies.erase( loaderIt );
			}
			else
				++loaderIt;
		}
		catch( ... ) {
			console() << "There was an error loading a movie." << std::endl;
			loaderIt = mLoadingMovies.erase( loaderIt );
		}
	}
}

void MovieAdvancedApp::draw()
{
	gl::clear();
	
	int totalWidth = 0;
	for( size_t m = 0; m < mMovies.size(); ++m )
		totalWidth += mMovies[m]->getWidth();
	
	int drawOffsetX = 0;
	for( size_t m = 0; m < mMovies.size(); ++m ) {
		float relativeWidth = mMovies[m]->getWidth() / (float)totalWidth;
		gl::Texture texture = mMovies[m]->getTexture();
		if( texture ) {
			float drawWidth = getWindowWidth() * relativeWidth;
			float drawHeight = ( getWindowWidth() * relativeWidth ) / mMovies[m]->getAspectRatio();
			float x = drawOffsetX;
			float y = ( getWindowHeight() - drawHeight ) / 2.0f;
			
			gl::color( Color::white() );
			gl::draw( texture, Rectf( x, y, x + drawWidth, y + drawHeight ) );
			texture.disable();
		}
		drawOffsetX += getWindowWidth() * relativeWidth;
	}
}

CINDER_APP_NATIVE( MovieAdvancedApp, RendererGl )
