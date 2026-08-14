package io.newgrounds.helpers {
	
	import io.newgrounds.AppState;
	
	/**
	 * AppStateResultUpdateHelper
	 *
	 * Applies typed API result models into AppState cache fields.
	 */
	public class AppStateResultUpdateHelper {
		
		/**
		 * Applies a single result object to AppState and finalizes session persistence state.
		 */
		public static function applyResult(appState:AppState, resultObject:*):void {
			var objectName:String = resultObject.objectName || resultObject.component || "";

			// Results describing ANOTHER app's data must never reach these caches.
			// AppState models one app - the one this client is running as - so
			// merging a foreign medal list would replace it wholesale and mark it
			// loaded, and NGIO.getMedals() would then hand the game somebody
			// else's medals as though they were its own.
			if (!isForeignAppResult(resultObject)) {
				applyGatewayResult(appState, objectName, resultObject);
				applySessionResult(appState, objectName, resultObject);
				applyAppVersionResult(appState, objectName, resultObject);
				applyHostLicenseResult(appState, objectName, resultObject);
				applyCloudSaveResult(appState, objectName, resultObject);
				applyMedalResult(appState, objectName, resultObject);
				applyScoreBoardResult(appState, objectName, resultObject);
			}

			// Session bookkeeping is about who is signed in, not about which app
			// the payload described, so it runs either way.
			appState.finalizeSessionPersistenceState();
		}

		/**
		 * Detects a result carrying data loaded from a different app.
		 *
		 * Four components accept an app_id parameter, letting an approved app read
		 * another app's data: Medal.getList, ScoreBoard.getScores,
		 * CloudSave.loadSlot and CloudSave.loadSlots. Their results echo that id
		 * back, and leave it null for ordinary local calls - so the server tells us
		 * directly, and no request-to-response correlation is needed.
		 *
		 * @return true if this result belongs to some other app
		 */
		private static function isForeignAppResult(resultObject:*):Boolean {
			if (resultObject == null || !resultObject.hasOwnProperty("app_id")) {
				return false;
			}

			var sourceAppId:String = resultObject.app_id as String;

			// Absent means "this is our own data" - the common case
			if (sourceAppId == null || sourceAppId.length == 0) {
				return false;
			}

			// The gateway only sets this for external lookups, but compare against
			// our own id anyway: a server that echoed the local id on every call
			// would otherwise make every result look foreign and silently stop all
			// AppState caching.
			if (resultObject.core != null && sourceAppId == resultObject.core.appId) {
				return false;
			}

			return true;
		}
		
		private static function applyGatewayResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "Gateway.getVersion") {
				appState.gatewayVersion = resultObject.version;
				appState.markLoaded("gatewayVersion");
			}
		}
		
		private static function applySessionResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName != "App.checkSession" && objectName != "App.startSession") {
				return;
			}
			
			if (appState.session == null) {
				// Note: no markLoaded("session") here - 'session' is not one of
				// AppState.dataProperties (it isn't loadable via loadData), and
				// markLoaded throws on names outside that list.
				appState.session = resultObject.session;
			} else {
				if (appState.session.hasOwnProperty("importFromObject")) {
					appState.session.importFromObject(resultObject.session);
				} else {
					for (var key:String in resultObject.session) {
						appState.session[key] = resultObject.session[key];
					}
				}
			}
			
			appState.session.error = resultObject.error;
			if (appState.session.expired !== true && appState.session.error == null) {
				appState.session.verified = true;
			}
		}
		
		private static function applyAppVersionResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "App.getCurrentVersion") {
				appState.currentVersion = resultObject.current_version;
				appState.clientDeprecated = resultObject.client_deprecated;
				appState.markLoaded("currentVersion");
			}
		}
		
		private static function applyHostLicenseResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "App.getHostLicense") {
				appState.hostApproved = resultObject.host_approved;
				appState.markLoaded("hostApproved");
			}
		}
		
		private static function applyCloudSaveResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "CloudSave.loadSlots") {
				// A failed component still reaches here, carrying no payload.
				// Caching that null and marking the property loaded would make
				// hasLoaded('saveSlots') answer true for data we never received,
				// so getSaveSlot() would stop warning and just return null.
				if (resultObject.slots == null) {
					return;
				}
				if (appState.saveSlots == null) {
					appState.saveSlots = resultObject.slots;
					appState.markLoaded("saveSlots");
				} else {
					updateCollectionById(appState.saveSlots, resultObject.slots);
				}
				return;
			}
			
			// All three return the same single 'slot' payload and want identical
			// handling. Leaving one out leaves the cached SaveSlot the UI is holding
			// reporting a stale size, timestamp and url - and hasData() answering
			// from it. loadSlot was the one missing.
			if (objectName == "CloudSave.loadSlot"
			    || objectName == "CloudSave.setData"
			    || objectName == "CloudSave.clearSlot") {
				if (appState.saveSlots != null) {
					updateSingleById(appState.saveSlots, resultObject.slot);
				}
			}
		}
		
		private static function applyMedalResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "Medal.getList") {
				// See the note in applyCloudSaveResult: a failed getList has no
				// medals to cache, and must not be recorded as loaded.
				if (resultObject.medals == null) {
					return;
				}
				if (appState.medals == null) {
					appState.medals = resultObject.medals;
					appState.markLoaded("medals");
				} else {
					updateCollectionById(appState.medals, resultObject.medals);
				}
				return;
			}

			if (objectName == "Medal.getMedalScore") {
				appState.medalScore = resultObject.medal_score;
				appState.markLoaded("medalScore");
				return;
			}

			if (objectName == "Medal.unlock") {
				// Only trust the score when the unlock actually succeeded. A
				// rejected unlock reports medal_score as its 0 default, which
				// would otherwise wipe the cached total.
				if (resultObject.medal != null) {
					appState.medalScore = resultObject.medal_score;
					appState.markLoaded("medalScore");
					updateSingleById(appState.medals, resultObject.medal);
				}
			}
		}
		
		private static function applyScoreBoardResult(appState:AppState, objectName:String, resultObject:*):void {
			if (objectName == "ScoreBoard.getBoards") {
				// See the note in applyCloudSaveResult
				if (resultObject.scoreboards == null) {
					return;
				}
				if (appState.scoreBoards == null) {
					appState.scoreBoards = resultObject.scoreboards;
					appState.markLoaded("scoreBoards");
				} else {
					updateCollectionById(appState.scoreBoards, resultObject.scoreboards);
				}
			}
		}
		
		private static function updateCollectionById(existingCollection:Array, incomingCollection:Array):void {
			if (existingCollection == null || incomingCollection == null) {
				return;
			}

			for each (var incoming:* in incomingCollection) {
				updateSingleById(existingCollection, incoming);
			}
		}

		private static function updateSingleById(existingCollection:Array, incoming:*):void {
			// A component that FAILED still produces a result model, but with its
			// payload object absent: Medal.unlock with an unknown id returns an
			// error and no 'medal'. There is nothing to merge in that case.
			//
			// Without this guard, reading incoming.id threw TypeError #1009 out of
			// applyResult(), which Core caught and reported as a generic
			// "Invalid response received from server" (505) - burying the real
			// error the server sent. Worse, the throw aborted applyResult() partway,
			// so finalizeSessionPersistenceState() never ran and, in a batched
			// request, every result after the failing one was silently never
			// applied to AppState.
			if (existingCollection == null || incoming == null) {
				return;
			}

			for each (var existing:* in existingCollection) {
				if (existing != null && existing.id == incoming.id) {
					if (existing.hasOwnProperty("importFromObject")) {
						existing.importFromObject(incoming);
					}
				}
			}
		}
	}
}
