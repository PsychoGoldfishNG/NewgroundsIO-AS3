/**
 * NGIO
 * 
 * Static wrapper class that simplifies Newgrounds.io API usage
 * 
 * This class provides an easy-to-use interface for developers. Instead of dealing with
 * complex Core objects and component models, developers can call simple static methods like
 * NGIO.unlockMedal() or NGIO.checkSession() and the wrapper handles all the complexity.
 * 
 * DESIGN: All properties and methods are static (class-level), so developers never need to create
 * an instance - they just use NGIO.methodName() directly. This is convenient and prevents
 * accidental creation of multiple wrapper instances.
 * 
 * NAMESPACE: (none - this is intentionally the only non-namespaced class for developer convenience)
 */
package {
	
	import io.newgrounds.helpers.NgioAuthHelper;
	import io.newgrounds.helpers.NgioBootstrapHelper;
	import io.newgrounds.helpers.NgioEventHelper;
	import io.newgrounds.helpers.NgioGatewayHelper;
	import io.newgrounds.helpers.NgioLoaderHelper;
	import io.newgrounds.Core;
	import io.newgrounds.SessionStatus;
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.models.results.App.checkSessionResult;
    import io.newgrounds.models.objects.Session;
    import io.newgrounds.models.objects.User;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.ScoreBoard;
    import io.newgrounds.models.objects.SaveSlot;
	import io.newgrounds.Errors;
	import flash.utils.Timer;
    import flash.display.MovieClip;
    
	public class NGIO {
		
		//==================== PUBLIC STATIC PROPERTIES ====================
        
        /**
         * If using our Medal Popup component, it will create a global reference
         * to itself using this variable.
         */
        public static var medalPopup:MovieClip = null;

		/**
		 * If using our ScoreBoard component, it will create a global reference
		 * to itself using this variable.
		 */
		public static var scoreBoardComponent:MovieClip = null;

        /**
         * Adjust the volume value if you want NGIO components to be quieter
         */
        public static var audio:Object = { 
            volume: 1,
            muted: false
        };

		//==================== READ-ONLY STATIC PROPERTIES ====================
		
		/**
		 * Reference to the Core instance for advanced users needing direct access
		 * Allows developers to execute custom components or access lower-level API if needed
		 * Most developers won't need this - use the public NGIO methods instead
		 */
		public static var core:Core = null;
		
		//==================== CONSTANTS ====================
		
		/**
		 * Prevents flooding the server with repeated session check requests
		 * Won't check more than once every 3 seconds
		 */
		public static const CHECKSESSION_THROTTLE_TIME:Number = 3;
		
		/**
		 * How often to keep active user sessions alive by "pinging" the server
		 * 300 seconds = 5 minutes
		 */
		public static const KEEP_ALIVE_TIME:Number = 300;
		
		//==================== PRIVATE STATIC PROPERTIES ====================
		
		/**
		 * Timer that periodically pings the server to keep sessions alive
		 */
		private static var keepAliveTimer:Timer = null;
		
		//==================== PUBLIC STATIC METHODS ====================
		
		/**
		 * Sets up the entire Newgrounds.io system. Must be called before using any other methods.
		 * 
		 * @param appId Your app's unique identifier from Newgrounds
		 * @param encryptionKey The encryption key from Newgrounds
		 * @param buildVersion Your app's version number in XX.XX.XXXX format (optional)
		 * @param useDebugMode If true, API calls won't actually save to the server (optional)
		 */
		public static function init(appId:String, encryptionKey:String, buildVersion:String = null, useDebugMode:Boolean = false):void 
		{
			if (core !== null) {
				trace("Warning: NGIO has already been initialized");
				return;
			}

			core = NgioBootstrapHelper.doInitializationSequence(appId, encryptionKey, buildVersion, useDebugMode);
			keepAliveTimer = NgioBootstrapHelper.startKeepAlive(KEEP_ALIVE_TIME, keepAlive);
		}
		
		/**
		 * Quickly check if we have an active session without contacting the server
		 * This is a local check only - it doesn't verify the session with the server
		 * 
		 * @return true if we have a valid session that hasn't expired, false otherwise
		 */
		public static function hasSession():Boolean {
			// First verify the wrapper is initialized
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// Check if session exists and is valid
			if (core.appState.session == null || 
			    core.appState.session.id == null || 
			    core.appState.session.id.length == 0 ||
			    core.appState.session.expired === true) {
				return false;
			}
			
			return true;
		}
		
		/**
		 * Check if we have a logged-in user (authenticated session)
		 * 
		 * @return true if user is logged in, false otherwise
		 */
		public static function hasUser():Boolean {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// First check if we even have a valid session
			if (!hasSession()) {
				return false;
			}
			
			// Then check if there's a user object attached to that session
			if (core.appState.session.user == null) {
				return false;
			}
			
			return true;
		}
		
		/**
		 * Get the logged-in user object, or null if no user is logged in
		 * 
		 * @return A User object containing user info, or null
		 */
		public static function getUser():* {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// If we have a user, return it
			if (hasUser()) {
				return core.appState.session.user;
			}
			
			// Otherwise return null to indicate no user
			return null;
		}
		
		/**
		 * Opens the Newgrounds login window so the user can authenticate
		 * NOTE: This must be called from a user click event in web-based applications
		 * 
		 * @param target Browser window target ("_blank" = new tab)
		 * @return true if passport was opened, false if it couldn't be opened
		 */
		public static function openPassport(target:String = "_blank"):Boolean {
			return NgioAuthHelper.openPassport(core, target);
		}
		
		/**
		 * Pings the server to keep the current authenticated session alive
		 * Sessions expire after a period of inactivity. This ping resets the expiration timer.
		 * Usually called automatically by a timer
		 */
		public static function keepAlive():void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// Only keep alive authenticated sessions (sessions with a logged-in user)
			// Guest sessions don't need to be kept alive
			if (!hasUser()) {
				return;
			}
			
			// Send a ping to the server to keep the session alive
			var pingComponent:* = ObjectFactory.CreateComponent("Gateway", "ping", null, core);
			if (pingComponent == null) {
				throw new Error("Could not create Gateway.ping component");
			}
			core.executeComponent(pingComponent as io.newgrounds.BaseComponent, null);
		}
		
		/**
		 * Check the current session status and report back via callback
		 * This is asynchronous - the callback will be called later when the server responds
		 * 
		 * @param callback Function to call when done. Receives SessionStatus object
		 * @param thisArg Scope for callback (optional)
		 */
		public static function checkSession(callback:Function, thisArg:* = null):void {
			NgioAuthHelper.checkSession(core, callback, thisArg);
		}
		
		/**
		 * Log the user out and end the session
		 * 
		 * @param callback Function to call when logout is complete (optional)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function endSession(callback:Function = null, thisArg:* = null):void {
			NgioAuthHelper.endSession(core, callback, thisArg);
		}
		
		/**
		 * Load metadata about the app from the server (versions, medals, scoreboards, etc.)
		 * 
		 * @param propertyNames Array of property names to load (e.g., ['medals', 'scoreboards'])
		 * @param callback Function called when done - receives (error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadAppData(propertyNames:Array, callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// Wrap the callback to adapt from AppState's (appState, error) signature to simple (error) signature
			var wrappedCallback:Function = null;
			if (callback !== null) {
				wrappedCallback = function(appState:*, error:*):void {
					// Call user's callback with just the error (or null if success)
					callback.call(thisArg, error);
				};
			}
			
			// This is a convenience wrapper around AppState.loadData()
			core.appState.loadData(propertyNames, wrappedCallback, null);
		}
		
		/**
		 * Get the cached gateway version, or null if not yet loaded
		 * This doesn't contact the server - it just returns what's cached locally
		 * 
		 * @return Gateway version string or null
		 */
		public static function getGatewayVersion():String {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.gatewayVersion;
		}
		
		/**
		 * Load the current Newgrounds gateway version from the server
		 * 
		 * @param callback Function called with (gatewayVersion, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadGatewayVersion(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['gatewayVersion'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.gatewayVersion, error);
				}
			}, thisArg);
		}
		
		/**
		 * Get the cached current app version from the server, or null if not loaded
		 * 
		 * @return Current version string or null
		 */
		public static function getCurrentVersion():String {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.currentVersion;
		}
		
		/**
		 * Load the current production version from server
		 * 
		 * @param callback Function called with (currentVersion, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadCurrentVersion(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['currentVersion'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.currentVersion, error);
				}
			}, thisArg);
		}
		
		/**
		 * Check if current version differs from server's production version
		 * 
		 * @return true if client is deprecated, false otherwise
		 */
		public static function getClientDeprecated():Boolean {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.clientDeprecated;
		}
		
		/**
		 * Check if the local build version differs from server's production version
		 * 
		 * @param callback Function called with (clientDeprecated, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadClientDeprecated(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['currentVersion'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.clientDeprecated, error);
				}
			}, thisArg);
		}
		
		/**
		 * Check if current domain is approved to run this app
		 * 
		 * @return true if host is approved, false otherwise
		 */
		public static function getHostApproved():Boolean {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.hostApproved;
		}
		
		/**
		 * Load host approval status from server
		 * 
		 * @param callback Function called with (hostApproved, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadHostApproved(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['hostApproved'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.hostApproved, error);
				}
			}, thisArg);
		}
		
		/**
		 * Get cached list of medals, or null if not loaded
		 * 
		 * @return Array of Medal objects or null
		 */
		public static function getMedals():Array {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.medals;
		}
		
		/**
		 * Load list of medals from server
		 * 
		 * @param callback Function called with (medals, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadMedals(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['medals'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.medals, error);
				}
			}, thisArg);
		}
		
		/**
		 * Get cached total medal score, or 0 if not loaded
		 * 
		 * @return Medal score number
		 */
		public static function getMedalScore():Number {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.medalScore;
		}
		
		/**
		 * Load user's total medal score from server
		 * 
		 * @param callback Function called with (medalScore, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadMedalScore(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['medalScore'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.medalScore, error);
				}
			}, thisArg);
		}
		
		/**
		 * Find and return a specific medal by ID
		 * 
		 * @param medalId The ID of the medal to find
		 * @return Medal object or null if not found
		 */
		public static function getMedal(medalId:int):* {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			// Check if medals have been loaded
			if (!core.appState.hasLoaded('medals')) {
				trace("WARNING: Medal data not loaded. Call loadMedals() first.");
				return null;
			}
			
			// Search for matching medal
			if (core.appState.medals !== null) {
				for each (var medal:* in core.appState.medals) {
					if (medal.id == medalId) {
						return medal;
					}
				}
			}
			
			// Not found
			return null;
		}
		
		/**
		 * Get cached list of scoreboards, or null if not loaded
		 * 
		 * @return Array of ScoreBoard objects or null
		 */
		public static function getScoreBoards():Array {
			if (core == null) {
				throw new Error("Core not initialized");
			}

			return core.appState.scoreBoards;
		}
		
		/**
		 * Load list of scoreboards from server
		 * 
		 * @param callback Function called with (scoreBoards, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadScoreBoards(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['scoreBoards'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.scoreBoards, error);
				}
			}, thisArg);
		}
		
		/**
		 * Find and return a specific scoreboard by ID
		 * 
		 * @param boardId The ID of the scoreboard to find
		 * @return ScoreBoard object or null if not found
		 */
		public static function getScoreBoard(boardId:int):* {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			if (!core.appState.hasLoaded('scoreBoards')) {
				trace("WARNING: ScoreBoard data not loaded. Call loadScoreBoards() first.");
				return null;
			}
			
			// Search for matching scoreboard
			if (core.appState.scoreBoards !== null) {
				for each (var board:* in core.appState.scoreBoards) {
					if (board.id == boardId) {
						return board;
					}
				}
			}
			
			// Not found
			return null;
		}
		
		//==================== CLOUD SAVES ====================
		
		/**
		 * Get cached list of cloud save slots, or null if not loaded
		 * 
		 * @return Array of SaveSlot objects or null
		 */
		public static function getSaveSlots():Array {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			return core.appState.saveSlots;
		}
		
		/**
		 * Load list of cloud save slots from server
		 * 
		 * @param callback Function called with (saveSlots, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadSaveSlots(callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			core.appState.loadData(['saveSlots'], function(appState:*, error:*):void {
				if (callback !== null) {
					callback.call(thisArg, core.appState.saveSlots, error);
				}
			}, thisArg);
		}
		
		/**
		 * Find and return a specific save slot by ID
		 * 
		 * @param slotId The ID of the save slot to find
		 * @return SaveSlot object or null if not found
		 */
		public static function getSaveSlot(slotId:int):* {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			if (!core.appState.hasLoaded('saveSlots')) {
				trace("WARNING: SaveSlot data not loaded. Call loadSaveSlots() first.");
				return null;
			}
			
			if (core.appState.saveSlots !== null) {
				for each (var saveSlot:* in core.appState.saveSlots) {
					if (saveSlot.id == slotId) {
						return saveSlot;
					}
				}
			}
			
			return null;
		}
		
		//==================== SERVER UTILITIES & EVENTS ====================
		// NOTE: Gateway and Event behavior is implemented in helper classes.
		// NGIO methods here are intentionally thin wrappers.
        
        /**
        * Get current server time in ISO 8601 format
        * 
        * @param callback Function called with (dateTime, error)
        * @param thisArg Scope for callback (optional)
        */
        public static function loadGatewayDateTime(callback:Function, thisArg:* = null):void {
			NgioGatewayHelper.loadGatewayDateTime(core, callback, thisArg);
        }
        
        /**
        * Get current server time as UNIX timestamp
        * 
        * @param callback Function called with (timestamp, error)
        * @param thisArg Scope for callback (optional)
        */
        public static function loadGatewayTimestamp(callback:Function, thisArg:* = null):void {
			NgioGatewayHelper.loadGatewayTimestamp(core, callback, thisArg);
        }
		
		/**
		* Get current server time as native Date object
		* 
		* Uses the gateway timestamp and converts it to Date via:
		* new Date(timestamp * 1000)
		* 
		* @param callback Function called with (date, error)
		* @param thisArg Scope for callback (optional)
		*/
		public static function loadGatewayDate(callback:Function, thisArg:* = null):void {
			NgioGatewayHelper.loadGatewayDate(core, callback, thisArg);
		}
        
        /**
        * Send a simple ping to test server connectivity
        * 
        * @param callback Function called with (pong, error) - pong is 'pong' string on success
        * @param thisArg Scope for callback (optional)
        */
        public static function sendPing(callback:Function = null, thisArg:* = null):void {
			NgioGatewayHelper.sendPing(core, callback, thisArg);
        }
        
        /**
        * Log a custom event to server for tracking
        * 
        * @param eventName Name of the event to log
        * @param callback Function called with (error) - optional
        * @param thisArg Scope for callback (optional)
        */
        public static function logEvent(eventName:String, callback:Function = null, thisArg:* = null):void {
			NgioEventHelper.logEvent(core, eventName, callback, thisArg);
        }
	
        //==================== URL NAVIGATION ====================

		/**
		 * Open URL where latest official version can be found in a new browser window
		 * NOTE: This must be called from a user click event in web-based applications (security requirement)
		 * 
		 * @param target Browser window target ("_blank" = new tab, optional)
		 * @param logEvent Log this action (optional, default true)
		 */
		public static function openOfficialUrl(target:String = "_blank", logEvent:Boolean = true):void {
			NgioLoaderHelper.openUrl(core, "loadOfficialUrl", target, logEvent);
		}
		
		/**
		 * Load URL where latest official version can be found (asynchronously)
		 * 
		 * @param logEvent Log this action (optional, default true)
		 * @param callback Function called with (url, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadOfficialUrl(logEvent:Boolean = true, callback:Function = null, thisArg:* = null):void {
			NgioLoaderHelper.loadUrl(core, "loadOfficialUrl", logEvent, callback, thisArg);
		}
		
		/**
		 * Open author's home page URL in a new browser window
		 * NOTE: This must be called from a user click event in web-based applications (security requirement)
		 * 
		 * @param target Browser window target ("_blank" = new tab, optional)
		 * @param logEvent Log this action (optional, default true)
		 */
		public static function openAuthorUrl(target:String = "_blank", logEvent:Boolean = true):void {
			NgioLoaderHelper.openUrl(core, "loadAuthorUrl", target, logEvent);
		}
		
		/**
		 * Load author's home page URL (asynchronously)
		 * 
		 * @param logEvent Log this action (optional, default true)
		 * @param callback Function called with (url, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadAuthorUrl(logEvent:Boolean = true, callback:Function = null, thisArg:* = null):void {
			NgioLoaderHelper.loadUrl(core, "loadAuthorUrl", logEvent, callback, thisArg);
		}
		
		/**
		 * Open author's "More Games" page URL in a new browser window
		 * NOTE: This must be called from a user click event in web-based applications (security requirement)
		 * 
		 * @param target Browser window target ("_blank" = new tab, optional)
		 * @param logEvent Log this action (optional, default true)
		 */
		public static function openMoreGames(target:String = "_blank", logEvent:Boolean = true):void {
			NgioLoaderHelper.openUrl(core, "loadMoreGames", target, logEvent);
		}
		
		/**
		 * Load author's "More Games" page URL (asynchronously)
		 * 
		 * @param logEvent Log this action (optional, default true)
		 * @param callback Function called with (url, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadMoreGames(logEvent:Boolean = true, callback:Function = null, thisArg:* = null):void {
			NgioLoaderHelper.loadUrl(core, "loadMoreGames", logEvent, callback, thisArg);
		}
		
		/**
		 * Open Newgrounds.com in a new browser window
		 * NOTE: This must be called from a user click event in web-based applications (security requirement)
		 * 
		 * @param target Browser window target ("_blank" = new tab, optional)
		 * @param logEvent Log this action (optional, default true)
		 */
		public static function openNewgrounds(target:String = "_blank", logEvent:Boolean = true):void {
			NgioLoaderHelper.openUrl(core, "loadNewgrounds", target, logEvent);
		}
		
		/**
		 * Load Newgrounds.com URL (asynchronously)
		 * 
		 * @param logEvent Log this action (optional, default true)
		 * @param callback Function called with (url, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadNewgrounds(logEvent:Boolean = true, callback:Function = null, thisArg:* = null):void {
			NgioLoaderHelper.loadUrl(core, "loadNewgrounds", logEvent, callback, thisArg);
		}
		
		/**
		 * Open a custom referral URL by name in a new browser window
		 * NOTE: This must be called from a user click event in web-based applications (security requirement)
		 * 
		 * @param referralName Name of referral configured in Newgrounds project
		 * @param target Browser window target ("_blank" = new tab, optional)
		 * @param logReferral Log this action (optional, default true)
		 */
		public static function openReferral(referralName:String, target:String = "_blank", logReferral:Boolean = true):void {
			NgioLoaderHelper.openUrl(core, "loadReferral", target, logReferral, referralName);
		}
		
		/**
		 * Load a custom referral URL by name (asynchronously)
		 * 
		 * @param referralName Name of referral configured in Newgrounds project
		 * @param logReferral Log this action (optional, default true)
		 * @param callback Function called with (url, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public static function loadReferral(referralName:String, logReferral:Boolean = true, callback:Function = null, thisArg:* = null):void {
			NgioLoaderHelper.loadUrl(core, "loadReferral", logReferral, callback, thisArg, referralName);
		}
	}
}
