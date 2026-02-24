/**
 * AppState
 * 
 * Stores and manages application state loaded from the server
 * 
 * This class acts as a cache and store for all data loaded from the server.
 * Instead of contacting the server every time you need medal info or scoreboard data,
 * AppState keeps a local copy that stays synchronized with the server.
 * 
 * WHY NEEDED: Making network requests is SLOW. By caching data locally, we can access it
 * instantly. When the server responds with updates, we update the cache in place (using
 * observer patterns) so object references stay valid.
 */
package io.newgrounds {
	
	import io.newgrounds.helpers.AppStateBootstrapHelper;
	import io.newgrounds.helpers.AppStateComponentHelper;
	import io.newgrounds.helpers.AppStateResultUpdateHelper;
	import io.newgrounds.helpers.AppStateSessionResetHelper;
	import io.newgrounds.helpers.AppStateSessionHelper;
	import io.newgrounds.models.objects.Session;
	import io.newgrounds.models.objects.Medal;
	import io.newgrounds.models.objects.ScoreBoard;
	import io.newgrounds.models.objects.SaveSlot;
	
	public class AppState {
		
		//==================== STATIC READONLY PROPERTIES ====================
		
		/**
		 * List of all app state properties that can be loaded from the server
		 * Used to validate property names - prevents typos like loadData(['meddles'])
		 */
		public static const dataProperties:Array = [
			'gatewayVersion',
			'currentVersion',
			'hostApproved',
			'saveSlots',
			'scoreBoards',
			'medals',
			'medalScore'
		];
		
		//==================== PRIVATE PROPERTIES ====================
		
		/**
		 * Tracks which properties have been loaded from the server
		 * hasLoaded('medals') checks if this array contains 'medals'
		 */
		private var dataLoaded:Array = [];
		
		/**
		 * Reference to the Core instance
		 * Need Core to queue components and execute requests
		 */
		private var core:Core;
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * Flag indicating whether Passport login window is currently open
		 * NGIO.checkSession() uses this flag to decide if it should wait
		 * before checking the server (user is probably still logging in)
		 */
		public var passportIsOpen:Boolean = false;
		
		//==================== READONLY PROPERTIES ====================
		
		/**
		 * The domain hosting this app (e.g., "uploads.ungrounded.net")
		 * Some Newgrounds features are domain-aware
		 */
		public var host:String = "N/A";
		
		/**
		 * Unique key for storing the session ID in browser localStorage
		 * Key includes App ID to avoid collisions between multiple apps
		 */
		public var sessionStorageKey:String = null;
		
		/**
		 * The current user session object
		 * Contains session ID, user info, expiration time, etc.
		 */
		public var session:Session = null;
		
		/**
		 * Version number of the Newgrounds gateway (e.g., "3.2.0")
		 * Used to notify developers if the gateway has been updated
		 */
		public var gatewayVersion:String = null;
		
		/**
		 * Latest version of this app as set in Newgrounds project settings
		 * If currentVersion > NGIO.buildVersion, app should notify user to update
		 */
		public var currentVersion:String = null;
		
		/**
		 * Flag set to true if app version is outdated
		 * Developers can check this flag to prompt users to update
		 */
		public var clientDeprecated:Boolean = false;
		
		/**
		 * Whether the domain hosting this app is approved in settings
		 * If hostApproved=false, app is running on unauthorized domain
		 */
		public var hostApproved:Boolean = true;
		
		/**
		 * Array of SaveSlot objects for cloud saves
		 * Stores metadata about cloud save slots
		 */
		public var saveSlots:Array = null;
		
		/**
		 * Array of ScoreBoard objects for leaderboards
		 */
		public var scoreBoards:Array = null;
		
		/**
		 * Array of Medal objects for achievements
		 */
		public var medals:Array = null;
		
		/**
		 * Total points earned from all unlocked medals, across all games
		 */
		public var medalScore:Number = 0;
		
		//==================== CONSTRUCTOR ====================
		
		/**
		 * Initialize AppState and attempt to restore previous session if available
		 * 
		 * @param core The Core instance this AppState is tied to
		 */
		public function AppState(core:Core) {
			// Store reference to Core
			this.core = core;
			
			// Create a new empty Session object
			this.session = new Session();
			this.session.id = null;
			
			// Create unique storage key including app ID
			// This prevents different apps from overwriting each other's session data
			this.sessionStorageKey = AppStateBootstrapHelper.getSessionStorageKey(core.appId);
			
			// Try to restore session from browser localStorage
			var savedSessionId:String = AppStateBootstrapHelper.getSavedSessionId(this.sessionStorageKey);

			if (savedSessionId != null && savedSessionId.length > 0) {
				// Restore the saved session ID
				this.session.id = savedSessionId;
			} else {
				// No saved session - try URL query string
				var sessionIdFromURL:String = AppStateBootstrapHelper.getSessionIdFromUrl();
                
				if (sessionIdFromURL != null && sessionIdFromURL.length > 0) {
                    this.session.preauthenticatedId = sessionIdFromURL;
                    this.session.id = sessionIdFromURL;
                }
			}
			
			// Determine the domain hosting this app
			this.host = AppStateBootstrapHelper.resolveHost();
		}
		
		//==================== PUBLIC METHODS ====================
		
		/**
		 * Bulk-load app data from the server (medals, scoreboards, versions, etc.)
		 * 
		 * Instead of loading each piece separately, batch them in one request for efficiency
		 * 
		 * @param propertyNames Array of property names to load (must exist in dataProperties)
		 * @param callback Function called when done - receives (appState, error)
		 * @param thisArg Scope for callback (optional)
		 */
		public function loadData(propertyNames:Array, callback:Function = null, thisArg:* = null):void {
			// Validate input
			if (propertyNames == null || propertyNames.length == 0) {
				throw new Error("propertyNames array is empty");
			}
			
			// Check that all requested properties are valid
			for each (var propertyName:String in propertyNames) {
				if (dataProperties.indexOf(propertyName) == -1) {
					throw new Error("Unknown property name: " + propertyName);
				}
			}
			
			var components:Array = AppStateComponentHelper.buildComponentsForProperties(propertyNames, this.core, this.host);
			for each (var component:* in components) {
				core.queueComponent(component as BaseComponent);
			}
			
			// Store error reference for callback
			var localError:* = null;
			
			// Execute all queued components in one request
			// NOTE: Response.importFromObject() already processes results and calls setValueFromResult()
			var self:AppState = this;
			core.executeQueue(function(response:*):void {
				// Get any error that occurred (if response is null or has error)
				if (response != null && response.error != null) {
					localError = response.error;
				}
				
				// Call the developer's callback with results
				if (callback != null) {
					callback.call(thisArg, self, localError);
				}
			}, thisArg);
		}
		
		/**
		 * Check whether a specific property has been loaded from the server
		 * 
		 * @param propertyName Property to check (must be in dataProperties)
		 * @return true if property has been loaded, false otherwise
		 */
		public function hasLoaded(propertyName:String):Boolean {
			// Validate the property name
			if (dataProperties.indexOf(propertyName) == -1) {
				throw new Error("Unknown property name: " + propertyName);
			}
			
			// Check if this property is in the loaded list
			return (dataLoaded.indexOf(propertyName) != -1);
		}
		
		/**
		 * Analyze the current session state and return a SessionStatus object
		 * 
		 * Provides a simple way for developers to understand the session state
		 * at a glance without digging through properties
		 * 
		 * NOTE: If session is expired/cancelled, this may clear session-scoped
		 * object data via the onSessionCleared callback path.
		 * 
		 * @return SessionStatus object with status code, user (if logged in), and error (if any)
		 */
		public function getSessionStatus():SessionStatus {
			return AppStateSessionHelper.getSessionStatus(this, this.onSessionCleared);
		}
		
		/**
		 * Updates app state properties from server result values
		 * 
		 * Called when a result object is parsed from server.
		 * Uses observer pattern to update existing objects instead of replacing them.
		 * 
		 * @param resultObject A result model that extends BaseResult
		 */
		public function setValueFromResult(resultObject:*):void {
			AppStateResultUpdateHelper.applyResult(this, resultObject);
		}
		
		/**
		 * Finalizes session persistence and passport-open state after result updates.
		 */
		public function finalizeSessionPersistenceState():void {
			if (this.session != null && this.session.remember === true) {
				AppStateBootstrapHelper.saveSessionId(this.sessionStorageKey, this.session.id);
			}
			
			if (this.passportIsOpen === true) {
				if (this.session == null || this.session.id == null || this.session.id.length == 0) {
					this.passportIsOpen = false;
				}
				if (this.session.expired === true) {
					this.passportIsOpen = false;
				}
				if (this.session.user != null) {
					this.passportIsOpen = false;
				}
			}
		}
		
		//==================== INTERNAL METHODS ====================
		// Exposed where needed so helper classes can delegate complex logic
		// while AppState remains the authoritative state container.
		
		/**
		 * Records that a property has been loaded from the server
		 *
		 * This is public so AppStateResultUpdateHelper can mark properties
		 * without duplicating AppState's validation rules.
		 * 
		 * @param propertyName Name of the property that has been loaded
		 */
		public function markLoaded(propertyName:String):void {
			// Validate that this is a valid property name
			if (dataProperties.indexOf(propertyName) == -1) {
				throw new Error("Unknown property name: " + propertyName);
			}
			
			// Check if already marked as loaded
			if (dataLoaded.indexOf(propertyName) != -1) {
				// Already marked as loaded, nothing to do
				return;
			}
			
			// Mark this property as loaded
			dataLoaded.push(propertyName);
		}
		
		/**
		 * Clears session-specific data from all affected objects
		 * 
		 * When a session expires or is cancelled, we need to reset objects to their
		 * unauthenticated state while preserving the cached data structure
		 */
		private function onSessionCleared():void {
			AppStateSessionResetHelper.clearSessionScopedData(this);
		}
		
		/**
		 * Completely clear the current session (used when logging out)
		 */
		public function clearSession():void {
			// Clear session-specific data from the session object
			if (session != null && session.hasOwnProperty("clearSessionData")) {
				session.clearSessionData();
			}
			
			// Also remove the saved session from browser storage
			// So next time they open the app, they won't be auto-logged-in
			AppStateBootstrapHelper.clearSavedSessionId(sessionStorageKey);
		}
	}
}
