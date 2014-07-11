#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"

#include "Avf.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class MovieAdvancedApp : public AppNative {
  public:
	void setup();
    
	void touchesBegan( TouchEvent event );
	
	void update();
	void draw();
	
  private:
    void onReadySignal();
    
	void addActiveMovie( avf::MovieSurfaceRef movie );
	void loadMovieUrl( const std::string& urlString );
	void loadMovieFile( const fs::path& path );
	
    void emptyMovieBucket();
    void deleteMovie();
    void addMovie();
    
	fs::path mLastPath;
	// all of the actively playing movies
	vector<avf::MovieSurfaceRef> mMovies;
	// movies we're still waiting on to be loaded
	vector<avf::MovieLoaderRef> mLoadingMovies;
    bool mReady;
};

void MovieAdvancedApp::setup()
{
    mReady = false;
	srand( 133 );
    fs::path moviePath = getResourcePath("windtunnel_vectors_02w.mov");
    loadMovieFile(moviePath);
}

void MovieAdvancedApp::onReadySignal()
{
    mReady = true;
}

void MovieAdvancedApp::touchesBegan( TouchEvent event )
{
    addMovie();
}

void MovieAdvancedApp::emptyMovieBucket()
{
    mMovies.clear();
    mLoadingMovies.clear();
}

void MovieAdvancedApp::deleteMovie()
{
    if( ! mMovies.empty() )
        mMovies.erase( mMovies.begin() + ( rand() % mMovies.size() ) );
}

void MovieAdvancedApp::addMovie()
{
    vector<string> randomMovie;
    // Error: not working with HD color profile(1-1-1)
//    randomMovie.push_back( "http://movies.apple.com/movies/us/hd_gallery/gl1800/480p/bbc_earth_m480p.mov" );
//    randomMovie.push_back( "http://movies.apple.com/media/us/quicktime/guide/hd/480p/noisettes_m480p.mov" );
    randomMovie.push_back( "http://pdl.warnerbros.com/wbol/us/dd/med/northbynorthwest/quicktime_page/nbnf_airplane_explosion_qt_500.mov" );
    loadMovieUrl( randomMovie[rand() % randomMovie.size()] );
}

void MovieAdvancedApp::addActiveMovie( avf::MovieSurfaceRef movie )
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
	avf::MovieSurfaceRef movie;
	
	try {
		movie = avf::MovieSurface::create( moviePath );
		movie->getReadySignal().connect(std::bind(&MovieAdvancedApp::onReadySignal, this));
        
		addActiveMovie( movie );
		mLastPath = moviePath;
	}
	catch( ... ) {
		console() << "Unable to load the movie." << std::endl;
		return;
	}
}

void MovieAdvancedApp::update()
{
	// let's see if any of our loading movies have finished loading and can be made active
	for( vector<avf::MovieLoaderRef>::iterator loaderIt = mLoadingMovies.begin(); loaderIt != mLoadingMovies.end(); ) {
		try {
			if( (*loaderIt)->checkPlayThroughOk() ) {
				avf::MovieSurfaceRef movie = avf::MovieSurface::create( *loaderIt );
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

    if(!mReady) return;

	int totalWidth = 0;
	for( size_t m = 0; m < mMovies.size(); ++m )
		totalWidth += mMovies[m]->getWidth();
	
    if( totalWidth < 0 ) return;
    
	int drawOffsetX = 0;
	for( size_t m = 0; m < mMovies.size(); ++m ) {
		float relativeWidth = mMovies[m]->getWidth() / (float)totalWidth;
        
        ci::Surface surface = mMovies[m]->getSurface();
        if(!surface) break;
        
		gl::Texture texture = gl::Texture(surface);
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