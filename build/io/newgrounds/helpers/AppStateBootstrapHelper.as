package io.newgrounds.helpers {
	
	import flash.display.LoaderInfo;
	import flash.net.LocalConnection;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.net.SharedObject;
	
	/**
	 * AppStateBootstrapHelper
	 *
	 * Handles AppState startup concerns: session key generation,
	 * session restore/persist helpers, runtime URL parsing, and host resolution.
	 */
	public class AppStateBootstrapHelper {
		
		/**
		 * Builds the per-app local storage key for saved session IDs.
		 */
		public static function getSessionStorageKey(appId:String):String {
			return "ngio-saved-session-id-for-" + appId;
		}
		
		/**
		 * Reads a previously saved session ID from local storage.
		 */
		public static function getSavedSessionId(sessionStorageKey:String):String {
			return getFromLocalStorage(sessionStorageKey);
		}
		
		/**
		 * Persists the current session ID to local storage.
		 */
		public static function saveSessionId(sessionStorageKey:String, sessionId:String):void {
			saveToLocalStorage(sessionStorageKey, sessionId);
		}
		
		/**
		 * Clears the persisted session ID from local storage.
		 */
		public static function clearSavedSessionId(sessionStorageKey:String):void {
			clearFromLocalStorage(sessionStorageKey);
		}
		
		/**
		 * Extracts ngio_session_id from the runtime URL query string.
		 */
		public static function getSessionIdFromUrl():String {
			var currentUrl:String = getRuntimeUrl();
			if (currentUrl == null || currentUrl.length == 0) {
				return null;
			}
			
			try {
				var request:URLRequest = new URLRequest(currentUrl);
				var queryStart:int = request.url.indexOf("?");
				if (queryStart == -1) {
					return null;
				}
				
				var query:String = request.url.substring(queryStart + 1);
				if (query.length == 0) {
					return null;
				}
				
				var variables:URLVariables = new URLVariables(query);
				if (variables.hasOwnProperty("ngio_session_id")) {
					var sessionId:String = String(variables["ngio_session_id"]);
					return (sessionId.length > 0) ? sessionId : null;
				}
			} catch (e:Error) {
			}
			
			return null;
		}
		
		/**
		 * Returns the current runtime URL if available.
		 */
		public static function getRuntimeUrl():String {
			try {
				var loaderInfo:LoaderInfo = LoaderInfo.getLoaderInfoByDefinition(AppStateBootstrapHelper);
				if (loaderInfo != null && loaderInfo.url != null && loaderInfo.url.length > 0) {
					return loaderInfo.url;
				}
			} catch (e:Error) {
			}
			return null;
		}
		
		/**
		 * Resolves the host/domain currently running the app.
		 */
		public static function resolveHost():String {
			var lc:LocalConnection = new LocalConnection();
			return lc.domain;
		}
		
		private static function getFromLocalStorage(key:String):String {
			try {
				var so:SharedObject = SharedObject.getLocal("ngio");
				if (so.data.hasOwnProperty(key)) {
					return so.data[key] as String;
				}
			} catch (e:Error) {
			}
			return null;
		}
		
		private static function saveToLocalStorage(key:String, value:String):void {
			try {
				var so:SharedObject = SharedObject.getLocal("ngio");
				so.data[key] = value;
				so.flush();
			} catch (e:Error) {
			}
		}
		
		private static function clearFromLocalStorage(key:String):void {
			try {
				var so:SharedObject = SharedObject.getLocal("ngio");
				delete so.data[key];
				so.flush();
			} catch (e:Error) {
			}
		}
		
	}
}
