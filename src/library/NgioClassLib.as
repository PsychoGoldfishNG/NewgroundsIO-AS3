package {
	/**
	 * NgioClassLib
	 * 
	 * Pre-compilation library class for the entire NewgroundsIO-AS3 library.
	 * 
	 * This class ensures that all library classes are compiled when added to a
	 * Flash project. By importing the main entry points, all dependent classes
	 * are pulled in transitively and compiled.
	 * 
	 * Add an instance of this class to your FLA library to ensure the full
	 * NewgroundsIO-AS3 library is available for runtime use.
	 */
	
	// Main API wrapper
	import NGIO;
	
	// Core system
	import io.newgrounds.Core;
	import io.newgrounds.AppState;
	import io.newgrounds.SessionStatus;
	import io.newgrounds.Errors;
	import io.newgrounds.BaseObject;
	import io.newgrounds.BaseComponent;
	import io.newgrounds.BaseResult;
	
	// Event system
	import io.newgrounds.NgioEvent;
	import io.newgrounds.NGJSON;
	
	// Object factory (imports all components, results, and objects)
	import io.newgrounds.models.objects.ObjectFactory;
	
	// Helper classes
	import io.newgrounds.helpers.AppStateBootstrapHelper;
	import io.newgrounds.helpers.AppStateComponentHelper;
	import io.newgrounds.helpers.AppStateResultUpdateHelper;
	import io.newgrounds.helpers.AppStateSessionHelper;
	import io.newgrounds.helpers.AppStateSessionResetHelper;
	import io.newgrounds.helpers.CoreComponentCallHelper;
	import io.newgrounds.helpers.CoreQueueExecutionHelper;
	import io.newgrounds.helpers.CoreTransportHelper;
	import io.newgrounds.helpers.HttpRequestHelper;
	import io.newgrounds.helpers.HttpResponseHelper;
	import io.newgrounds.helpers.NgioAuthHelper;
	import io.newgrounds.helpers.NgioBootstrapHelper;
	import io.newgrounds.helpers.NgioEventHelper;
	import io.newgrounds.helpers.NgioGatewayHelper;
	import io.newgrounds.helpers.NgioLoaderHelper;
	
	// Cryptography library (com.hurlant)
	import com.hurlant.crypto.Crypto;
	
    /**
     * Using this as a MovieClip makes it easier to import into Flash projects, 
     * but it doesn't need to be instantiated or added to the stage for the library to work. 
     * The presence of this class in the library is enough to ensure all classes are 
     * compiled and available at runtime.
     */
    import flash.display.MovieClip;

	public class NgioClassLib extends MovieClip {
		public function NgioClassLib() {

            var _class:*;

			// refer to all classes to ensure they are included in compilation
            // Main API wrapper
            _class = NGIO;
            
            // Core system
            _class = io.newgrounds.Core;
            _class = io.newgrounds.AppState;
            _class = io.newgrounds.SessionStatus;
            _class = io.newgrounds.Errors;
            _class = io.newgrounds.BaseObject;
            _class = io.newgrounds.BaseComponent;
            _class = io.newgrounds.BaseResult;
            
            // Event system
            _class = io.newgrounds.NgioEvent;
            _class = io.newgrounds.NGJSON;
            
            // Object factory (imports all components, results, and objects)
            _class = io.newgrounds.models.objects.ObjectFactory;
            
            // Helper classes
            _class = io.newgrounds.helpers.AppStateBootstrapHelper;
            _class = io.newgrounds.helpers.AppStateComponentHelper;
            _class = io.newgrounds.helpers.AppStateResultUpdateHelper;
            _class = io.newgrounds.helpers.AppStateSessionHelper;
            _class = io.newgrounds.helpers.AppStateSessionResetHelper;
            _class = io.newgrounds.helpers.CoreComponentCallHelper;
            _class = io.newgrounds.helpers.CoreQueueExecutionHelper;
            _class = io.newgrounds.helpers.CoreTransportHelper;
            _class = io.newgrounds.helpers.HttpRequestHelper;
            _class = io.newgrounds.helpers.HttpResponseHelper;
            _class = io.newgrounds.helpers.NgioAuthHelper;
            _class = io.newgrounds.helpers.NgioBootstrapHelper;
            _class = io.newgrounds.helpers.NgioEventHelper;
            _class = io.newgrounds.helpers.NgioGatewayHelper;
            _class = io.newgrounds.helpers.NgioLoaderHelper;
            
            // Cryptography library (com.hurlant)
            _class = com.hurlant.crypto.Crypto;
		}
	}
}