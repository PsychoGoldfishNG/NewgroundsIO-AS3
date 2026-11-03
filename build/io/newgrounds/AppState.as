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
	import io.newgrounds.helpers.DateTimeHelper;
	import io.newgrounds.helpers.AppStateResultUpdateHelper;
	import io.newgrounds.helpers.AppStateSessionResetHelper;
	import io.newgrounds.helpers.AppStateSessionHelper;
	import io.newgrounds.models.objects.Session;
	import io.newgrounds.models.objects.Medal;
	import io.newgrounds.models.objects.ScoreBoard;
	import io.newgrounds.models.objects.SaveSlot;
	import io.newgrounds.models.objects.ObjectFactory;

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

		/**
		 * The local mirror of this app's save slots. Nothing outside AppState
		 * reaches it: the SaveSlot model goes through readLocalSlotData(),
		 * writeLocalSlotData() and clearLocalSlotData(), which keeps the merge in
		 * one place. See SAVE SLOT LOCAL FALLBACK below.
		 */
		private var localSaveSlots:LocalSaveSlotStore;

		/**
		 * How many CloudSave.loadSlots results have been merged. loadData()
		 * compares it before and after, to tell whether a slot list came back.
		 */
		private var slotListsMerged:int = 0;

		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * Flag indicating whether Passport login window is currently open
		 * NGIO.checkSession() uses this flag to decide if it should wait
		 * before checking the server (user is probably still logging in)
		 */
		public var passportIsOpen:Boolean = false;

		/**
		 * Whether a save made while nobody was signed in (a guest save) becomes the
		 * local copy of whoever signs in next. When false, guest saves stay
		 * guest-only: a signed-in player never sees them, and they're still there
		 * the next time nobody is signed in. Set through NGIO.offerGuestSaves.
		 */
		public var offerGuestSaves:Boolean = true;

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
		 *
		 * Only meaningful once your Newgrounds project has a version set in
		 * "Version Control" AND core.buildVersion is set. With no project version
		 * configured, leave core.buildVersion null or this can come back true for
		 * a deprecation that isn't real.
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

			// Scoped by App ID for the same reason as the session key
			this.localSaveSlots = new LocalSaveSlotStore(core.appId);

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
		
		//==================== RESULT ERROR INSPECTION ====================

		/**
		 * Every component-level failure in a response, as {component, error} pairs.
		 *
		 * A gateway request has THREE independent layers at which it can fail, and
		 * they mean different things:
		 *
		 *   1. TRANSPORT  no HTTP response arrived at all, or a non-2xx came back.
		 *                 Core.onHTTPResponse builds the error; nothing below runs.
		 *   2. ENVELOPE   response.success !== true. The request as a whole was
		 *                 rejected - bad app id, malformed body, unparseable reply.
		 *                 No component ran.
		 *   3. COMPONENT  result.success !== true. THIS component failed. Others in
		 *                 the same envelope may have succeeded perfectly well.
		 *
		 * Layer 3 exists because an envelope can carry several components at once,
		 * so "did it work" is not one question - it is one question per component,
		 * and the answer has to say WHERE. That is what this returns.
		 *
		 * Each entry names the component (from the result's objectName, e.g.
		 * "CloudSave.loadSlots") alongside its error, so a partial failure can be
		 * reported precisely rather than as an anonymous "something went wrong".
		 *
		 * @param response A Response model (or null)
		 * @return Array of {component:String, error:NgioError}; empty if all succeeded
		 */
		public static function resultErrors(response:*):Array {
			var found:Array = [];

			if (response == null) {
				return found;
			}

			// Both result shapes. executeQueue always sends the queue as an
			// execute list, so a response from loadData always carries
			// `resultList` - even for one property. This method is public,
			// though: a caller can hand it a single-component response from
			// executeComponent(), which carries the scalar `result` instead.
			var list:Array = response.getResultList();

			if (list == null) {
				collectResultError(response.getResult(), found);
				return found;
			}

			for each (var entry:* in list) {
				collectResultError(entry, found);
			}

			return found;
		}

		/**
		 * The first component-level failure, or null if every component succeeded.
		 *
		 * What loadData hands its callback. Reporting the first rather than all of
		 * them keeps the (appState, error) signature unchanged; callers wanting the
		 * full picture have two better tools - resultErrors() for the detail, and
		 * hasLoaded() to ask which properties actually arrived, since the ones that
		 * succeeded are still cached.
		 *
		 * @param response A Response model (or null)
		 * @return The first component's error, or null
		 */
		public static function firstResultError(response:*):* {
			var found:Array = resultErrors(response);
			return (found.length > 0) ? found[0].error : null;
		}

		/**
		 * The error on one result, or null when it succeeded.
		 *
		 * A result that reports success !== true but carries no error still has to
		 * produce something, or the caller is back to a silent failure.
		 *
		 * @param result A single BaseResult (or null)
		 * @return The result's error, a synthesised INVALID_RESPONSE, or null
		 */
		public static function resultError(result:*):* {
			if (result == null) {
				return null;
			}

			if (result.success === true) {
				return null;
			}

			if (result.error != null) {
				return result.error;
			}

			return Errors.getError(Errors.INVALID_RESPONSE, null, false);
		}

		/**
		 * Append one result's failure to `found`, if it failed.
		 *
		 * Private here; its AS2 twin is public only because AS2 cannot resolve a
		 * private static from inside a nested function.
		 */
		private static function collectResultError(result:*, found:Array):void {
			var error:* = resultError(result);

			if (error == null) {
				return;
			}

			// objectName is the component path the result belongs to. A result the
			// factory could not type has none - and BaseObject's getter throws
			// rather than returning null - but it is still worth reporting, just
			// without a name.
			var componentName:String = "(unidentified component)";

			try {
				if (result.objectName != null) {
					componentName = String(result.objectName);
				}
			} catch (e:Error) {
				// Leave the placeholder in place.
			}

			found.push({ component: componentName, error: error });
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

			var wantsSlots:Boolean = propertyNames.indexOf('saveSlots') != -1;
			var slotListsBefore:int = this.slotListsMerged;

			// Execute all queued components in one request
			// NOTE: Response.importFromObject() already processes results and calls setValueFromResult()
			var self:AppState = this;
			core.executeQueue(function(response:*):void {
				// No slot list came back from the gateway: refused without being
				// sent (nobody signed in), or the request never got there. Neither
				// passes through setValueFromResult(), and that's the case the local
				// copies exist for, so merge them here.
				if (wantsSlots && self.slotListsMerged == slotListsBefore) {
					self.mergeWithoutCloudList();
				}

				// A failed load surfaces at any of THREE levels, and all of them
				// have to be checked - the same pattern NgioLoaderHelper.loadUrl,
				// Medal.unlock and ScoreBoard.getScores use. See resultErrors()
				// above for what the three layers mean.
				//
				// Only the envelope level was checked here. A request can succeed
				// while an individual COMPONENT is refused, and that is the common
				// case rather than an exotic one: ask for saveSlots or medalScore
				// without being logged in and the gateway returns
				//
				//   {"success":true,"result":[{"data":{"success":false,
				//     "error":{"code":110,"message":"User is not logged in."}}}]}
				//
				// - a successful response carrying a refused component. The caller
				// got (appState, null): no data and no reason. A game would read
				// that as "this user has no saves" rather than "this user is not
				// signed in", and NGIO.loadSaveSlots / loadMedalScore /
				// loadAppData all inherit it.
				if (response == null) {
					localError = Errors.getError(Errors.INVALID_RESPONSE, null, false);
				} else if (response.error != null) {
					localError = response.error;
				} else {
					localError = firstResultError(response);
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
		 * True for a result whose request went out for a session that is no longer the
		 * current one: the player signed out, or another session replaced it, while the
		 * request was in flight. The response import skips setValueFromResult() for it.
		 * The caller still receives the result.
		 *
		 * - App.checkSession / App.startSession: writing it in would put the old session
		 *   back, so any change of session counts, including from none.
		 * - Results that describe the signed-in player (medal unlocks, medal score, save
		 *   slots): stale only when sent FOR a session that has since gone. One sent with
		 *   no session describes nobody, so it is still good.
		 *
		 * Compares against the id the request carried, not an id in the result, so it
		 * never depends on what the server echoes back.
		 *
		 * @param resultObject A result model that extends BaseResult
		 * @param sentSessionId The session id the request carried, or null for none
		 */
		public function isStaleSessionResult(resultObject:*, sentSessionId:String):Boolean {
			if (resultObject == null) {
				return false;
			}

			var currentId:String = (session != null) ? session.id : null;
			if (currentId == "") currentId = null;
			if (sentSessionId == "") sentSessionId = null;

			switch (resultObject.objectName) {
				case "App.checkSession":
				case "App.startSession":
					return currentId !== sentSessionId;

				case "Medal.getList":
				case "Medal.getMedalScore":
				case "Medal.unlock":
				case "CloudSave.loadSlots":
				case "CloudSave.loadSlot":
				case "CloudSave.setData":
				case "CloudSave.clearSlot":
					return sentSessionId !== null && currentId !== sentSessionId;
			}
			return false;
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
				// Chained, not three independent checks: the first branch is
				// reached precisely when there is no session to interrogate, so
				// falling through to this.session.expired threw TypeError #1009
				// on any result that arrived after the session was cleared while
				// Passport was open - which is exactly when a login is cancelled.
				if (this.session == null || this.session.id == null || this.session.id.length == 0) {
					this.passportIsOpen = false;
				} else if (this.session.expired === true) {
					this.passportIsOpen = false;
				} else if (this.session.user != null) {
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
		 * Discard a session the server has rejected (expired or cancelled)
		 *
		 * Same reset as clearSession(); kept separate because the reason differs.
		 * Without it, a rejected session id stays in memory and in storage, so every
		 * later checkSession() re-sends the same dead id and fails the same way.
		 */
		public function invalidateSession():void {
			clearSession();
		}

		/**
		 * Completely clear the current session (used when logging out)
		 *
		 * Resets everything that described the old player, not just the session: the
		 * medals' and save slots' session data, medalScore and passportIsOpen. Otherwise
		 * the next player sees the last one's unlocks, and a sign-out while Passport
		 * was open leaves openPassport() refusing to open it again.
		 */
		public function clearSession():void {
			// Reset session-scoped state and the session object itself
			AppStateSessionResetHelper.clearSessionScopedData(this);

			// Drop any error left over from the old session, so a freshly started
			// session isn't immediately judged by the old session's failure
			if (this.session != null) {
				this.session.error = null;
			}

			// Also remove the saved session from browser storage
			// So next time they open the app, they won't be auto-logged-in
			AppStateBootstrapHelper.clearSavedSessionId(sessionStorageKey);
		}

		//==================== SAVE SLOT LOCAL FALLBACK ====================
		//
		// A save slot is meant to be stored on the cloud, with a local copy
		// protecting it from network loss and server outages. AppState is already
		// the save slot cache and setValueFromResult() is already the by-id merge
		// point, so choosing between two copies is that same job with one more
		// source.
		//
		// Sync is passive. A fresher local copy is used for display and loading but
		// never pushed on its own; it reaches the cloud on the player's next save,
		// or when the game resolves a conflict with SaveSlot.keepLocal().
		//
		// Local copies belong to whoever wrote them: the signed-in user, or a guest
		// when nobody is signed in. Every read and write goes through the current
		// owner, so one player's local copy never reaches another.

		/**
		 * Who local slot copies currently belong to.
		 *
		 * @return The signed-in user's id, or null for a guest
		 */
		public function getLocalSlotOwner():* {
			if (this.session == null || this.session.user == null) return null;
			return this.session.user.id;
		}

		/**
		 * Merges a CloudSave.loadSlots result's slots into the cache. Called by
		 * AppStateResultUpdateHelper. A rejected call arrives with null slots,
		 * which is the offline or signed-out case the local copies exist for, so
		 * it's merged like any other.
		 */
		public function applySlotListResult(cloudSlots:Array):void {
			this.slotListsMerged++;
			applySlotList(cloudSlots);
		}

		/** Merges a slot list into the cache, against the local copies. */
		private function applySlotList(cloudSlots:Array):void {
			var reconciled:Array = reconcileSaveSlots(cloudSlots);
			// Nothing from either copy. Caching nothing and marking it loaded would
			// make hasLoaded('saveSlots') true for data that never arrived.
			if (reconciled.length == 0) return;

			if (this.saveSlots == null) {
				this.saveSlots = reconciled;
				markLoaded('saveSlots');
				return;
			}

			// Update in place, never replace the array: the game may be holding
			// these slots.
			for each (var slot:SaveSlot in reconciled) {
				var cached:SaveSlot = findCachedSlot(slot.id);
				if (cached == null) {
					// An id the cache has never seen. A first list made while offline
					// holds only the local ids, so the cloud's arrive later.
					this.saveSlots.push(slot);
				} else if (cached !== slot) {
					cached.importFromObject(slot);
					// source isn't a schema property, so importFromObject() doesn't
					// carry it across.
					cached.source = slot.source;
				}
			}
			this.saveSlots.sortOn("id", Array.NUMERIC);
		}

		/**
		 * The merge for a loadData() that got no slot list back. The cached slots
		 * stand in for the cloud's: they're the last thing known about the cloud
		 * copies, so an older local copy can't replace a newer cloud one just
		 * because the network is down. A cached slot describing a local copy says
		 * nothing about the cloud, so it's left out. After a sign-out every cached
		 * slot is empty, and the new owner's local copies are listed as they are.
		 */
		private function mergeWithoutCloudList():void {
			if (this.saveSlots == null) {
				applySlotList(null);
				return;
			}
			applySlotList(this.saveSlots.filter(function(slot:*, index:int, all:Array):Boolean {
				return slot.source != "local";
			}));
		}

		private function findCachedSlot(id:Number):SaveSlot {
			if (this.saveSlots == null) return null;
			for each (var slot:SaveSlot in this.saveSlots) {
				if (slot != null && slot.id == id) return slot;
			}
			return null;
		}

		/**
		 * Builds the slot list from both copies, newest wins, and records each
		 * decision on the slot's source.
		 */
		private function reconcileSaveSlots(cloudSlots:Array):Array {
			var owner:* = getLocalSlotOwner();
			if (owner !== null && this.offerGuestSaves) adoptGuestSaves(owner);
			var registry:Object = this.localSaveSlots.getRegistry(owner);

			var cloudById:Object = {};
			var ids:Array = [];
			if (cloudSlots != null) {
				for each (var cloudSlot:* in cloudSlots) {
					if (cloudSlot == null) continue;
					cloudById[String(cloudSlot.id)] = cloudSlot;
					if (ids.indexOf(Number(cloudSlot.id)) == -1) ids.push(Number(cloudSlot.id));
				}
			}

			// The full slot id range, not just the ids the cloud returned: a slot
			// saved while offline exists locally and nowhere else.
			for (var key:String in registry) {
				var localId:Number = Number(key);
				if (!isNaN(localId) && localId == Math.floor(localId) && ids.indexOf(localId) == -1) {
					ids.push(localId);
				}
			}
			ids.sort(Array.NUMERIC);

			var merged:Array = [];
			for each (var id:Number in ids) {
				var local:Object = registry.hasOwnProperty(String(id)) ? registry[String(id)] : null;
				var chosen:SaveSlot = chooseSlotCopy(id, cloudById[String(id)] as SaveSlot, local);
				if (chosen != null) merged.push(chosen);
			}
			return merged;
		}

		/**
		 * Picks the newer of the two copies by ISO 8601 datetime. The cloud wins
		 * ties, since a save that round-tripped is the more complete state, and it
		 * wins an unreadable local datetime too (NaN fails the comparison).
		 *
		 * A newer local copy only wins outright when the cloud slot is empty or
		 * missing. When the cloud holds a save too, either choice loses one of
		 * them, so the slot is marked "conflict" for the game to ask the player.
		 * It keeps the cloud's fields, and loading it returns the local copy until
		 * the game calls keepLocal() or keepCloud().
		 */
		private function chooseSlotCopy(id:Number, cloud:SaveSlot, local:Object):SaveSlot {
			if (local == null) {
				if (cloud != null) cloud.source = "cloud";
				return cloud;
			}

			var localTime:Number = DateTimeHelper.parseIso(local.datetime);
			var cloudTime:Number = (cloud != null && cloud.datetime != null)
				? DateTimeHelper.parseIso(cloud.datetime)
				: Number.NEGATIVE_INFINITY;

			if (cloud != null && !(localTime > cloudTime)) {
				cloud.source = "cloud";
				return cloud;
			}

			if (cloud != null && cloud.url != null && cloud.url != "") {
				cloud.source = "conflict";
				return cloud;
			}

			var built:SaveSlot = buildLocalSlot(id, local);
			return (built != null) ? built : cloud;
		}

		/**
		 * A slot describing the local copy. It carries no url: there is nothing to
		 * fetch, and inventing one would send loadDataRaw() after a file that
		 * doesn't exist.
		 */
		private function buildLocalSlot(id:Number, entry:Object):SaveSlot {
			var parsed:Number = DateTimeHelper.parseIso(entry.datetime);
			var slot:SaveSlot = ObjectFactory.CreateObject("SaveSlot", {
				id: id,
				size: entry.size,
				datetime: entry.datetime,
				timestamp: isNaN(parsed) ? 0 : Math.floor(parsed / 1000),
				url: null
			}, this.core) as SaveSlot;
			if (slot == null) return null;
			slot.source = "local";
			return slot;
		}

		/**
		 * Moves guest copies into the signed-in player's own copies. A guest copy
		 * goes to whoever signs in next, and only to them: once offered it's
		 * removed from the guest copies. It replaces the player's own local copy
		 * only if it's newer. Otherwise it's simply dropped.
		 */
		private function adoptGuestSaves(owner:*):void {
			var guestRegistry:Object = this.localSaveSlots.getRegistry(null);
			for (var key:String in guestRegistry) {
				var id:Number = Number(key);
				if (isNaN(id) || id != Math.floor(id)) continue;
				var guest:Object = guestRegistry[key];
				var payload:String = this.localSaveSlots.getPayload(id, null);

				if (payload != null) {
					var own:Object = this.localSaveSlots.getEntry(id, owner);
					var guestIsNewer:Boolean = (own == null)
						|| DateTimeHelper.parseIso(guest.datetime) > DateTimeHelper.parseIso(own.datetime);
					// Keep the guest copy if it can't be moved, rather than losing it.
					if (guestIsNewer && !this.localSaveSlots.writeEntry(id, payload, owner, guest.datetime)) continue;
				}

				this.localSaveSlots.deleteEntry(id, null);
			}
		}

		/** The current owner's local save data for one slot, or null. Used by SaveSlot.loadDataRaw() and keepLocal(). */
		public function readLocalSlotData(id:Number):String {
			return this.localSaveSlots.getPayload(id, getLocalSlotOwner());
		}

		/**
		 * The current owner's local copy of one slot, as {size, datetime}, or null
		 * if there is none. Used by SaveSlot.getLocalCopy().
		 */
		public function getLocalSlotEntry(id:Number):Object {
			var entry:Object = this.localSaveSlots.getEntry(id, getLocalSlotOwner());
			return (entry == null) ? null : {size: entry.size, datetime: entry.datetime};
		}

		/**
		 * Stores one slot's local copy for the current owner, returning whether it
		 * was written. Used for the local leg of a save, the cache of a cloud
		 * load, and re-stamping a save the cloud accepted.
		 *
		 * @param datetime ISO 8601 stamp for the copy. Defaults to now. Pass the
		 *        cloud's own datetime when caching a cloud load.
		 */
		public function writeLocalSlotData(id:Number, data:String, datetime:String = null):Boolean {
			return this.localSaveSlots.writeEntry(id, data, getLocalSlotOwner(), datetime);
		}

		/** Drops the current owner's local copy of one slot. Used by SaveSlot.clearData() and keepCloud(). */
		public function clearLocalSlotData(id:Number):Boolean {
			return this.localSaveSlots.deleteEntry(id, getLocalSlotOwner());
		}
	}
}
