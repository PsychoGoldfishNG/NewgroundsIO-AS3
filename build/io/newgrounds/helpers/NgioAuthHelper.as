package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.Errors;
	import io.newgrounds.SessionStatus;
	import io.newgrounds.models.objects.ObjectFactory;
	import io.newgrounds.models.results.App.checkSessionResult;
	import flash.net.navigateToURL;
	import flash.net.URLRequest;
	
	/**
	 * NgioAuthHelper
	 *
	 * Handles NGIO session/authentication orchestration against App.* endpoints.
	 */
	public class NgioAuthHelper {
		
		private static const CHECKSESSION_THROTTLE_TIME:Number = 3;
		private static var lastCheckSessionTime:Date = null;
		
		/**
		 * Opens the Newgrounds login window so the user can authenticate.
		 *
		 * @param core The active NGIO core instance
		 * @param target Browser window target ("_blank" = new tab)
		 * @return true if passport was opened, false if it couldn't be opened
		 */
		public static function openPassport(core:Core, target:String = "_blank"):Boolean {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			if (core.appState.session == null || 
				core.appState.session.id == null || 
				core.appState.session.id.length == 0 ||
				core.appState.session.expired === true ||
				core.appState.session.user != null) {
				trace("WARNING: Cannot open passport - " + ((core.appState.session == null || core.appState.session.id == null || core.appState.session.id.length == 0 || core.appState.session.expired === true) ? "no session" : "user already logged in"));
				return false;
			}
			
			if (core.appState.passportIsOpen === true) {
				trace("WARNING: Cannot open passport - passport window already open");
				return false;
			}
			
			if (core.appState.session.passport_url == null || core.appState.session.passport_url.length == 0) {
				trace("WARNING: Cannot open passport - no passport URL available (call checkSession first)");
				return false;
			}
			
			try {
				var request:URLRequest = new URLRequest(core.appState.session.passport_url);
				navigateToURL(request, target);
				core.appState.passportIsOpen = true;
			} catch (e:Error) {
				trace("ERROR: Failed to open passport URL - " + e.message);
				return false;
			}
			
			return true;
		}
		
		/**
		 * Checks session state, performing startSession/checkSession as needed.
		 */
		public static function checkSession(core:Core, callback:Function, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}

			var callCallback:Function = function(status:SessionStatus):void {
				if (callback !== null) {
					callback.call(thisArg, status);
				}
			};
			
			var sessionStatus:SessionStatus = new SessionStatus();
			
			if (hasUser(core)) {
				sessionStatus.status = SessionStatus.LOGGED_IN;
				sessionStatus.user = core.appState.session.user;
				callCallback(sessionStatus);
				return;
			}
						
			if (lastCheckSessionTime !== null) {
				var timeSinceLastCheck:Number = (new Date().time - lastCheckSessionTime.time) / 1000;
				if (timeSinceLastCheck < CHECKSESSION_THROTTLE_TIME) {
					if (core.appState.passportIsOpen === true) {
						sessionStatus.status = SessionStatus.WAITING_FOR_PASSPORT;
					} else if (core.appState.session.verified !== true) {
						sessionStatus.status = SessionStatus.UNVERIFIED;
					} else {
						sessionStatus.status = SessionStatus.NOT_LOGGED_IN;
					}
					callCallback(sessionStatus);
					return;
				}
			}
			
			lastCheckSessionTime = new Date();
			
			if (!hasSession(core)) {
				var startSessionComponent:* = ObjectFactory.CreateComponent("App", "startSession", null, core);
				if (startSessionComponent == null) {
					throw new Error("Could not create App.startSession component");
				}
				core.executeComponent(startSessionComponent as io.newgrounds.BaseComponent, function(result:*):void {
					if (result !== null && result.success === true) {
						sessionStatus.status = SessionStatus.NOT_LOGGED_IN;
					} else if (result !== null && result.error !== null) {
						sessionStatus.status = SessionStatus.ERROR;
						sessionStatus.error = result.error;
					} else {
						sessionStatus.error = Errors.getError();
						sessionStatus.status = SessionStatus.ERROR;
					}
					callCallback(sessionStatus);
				});
				return;
			}
			
			var checkSessionComponent:* = ObjectFactory.CreateComponent("App", "checkSession", null, core);
			if (checkSessionComponent == null) {
				throw new Error("Could not create App.checkSession component");
			}
			core.executeComponent(checkSessionComponent as io.newgrounds.BaseComponent, function(response:io.newgrounds.models.objects.Response):void {
				var result:io.newgrounds.models.results.App.checkSessionResult = null;
				
				if (response !== null && response.success === true) {
					result = response.getResult() as io.newgrounds.models.results.App.checkSessionResult;
					
					if (result !== null && result.success === true) {
						if (core.appState.session.user !== null) {
							sessionStatus.status = SessionStatus.LOGGED_IN;
							sessionStatus.user = core.appState.session.user;
						} else if (core.appState.passportIsOpen === true) {
							sessionStatus.status = SessionStatus.WAITING_FOR_PASSPORT;
						} else {
							sessionStatus.status = SessionStatus.NOT_LOGGED_IN;
						}
					} else if (result !== null && result.error !== null) {
						if (result.error.code == Errors.CANCELLED_SESSION) {
							sessionStatus.status = SessionStatus.LOGIN_CANCELLED;
						} else {
							sessionStatus.status = SessionStatus.ERROR;
							sessionStatus.error = result.error;
						}
					} else {
						sessionStatus.error = Errors.getError();
					}
				} else {
					sessionStatus.status = SessionStatus.ERROR;
					if (result !== null && result.error !== null) {
						sessionStatus.error = result.error;
					} else {
						sessionStatus.error = Errors.getError();
					}
				}
				
				callCallback(sessionStatus);
			});
		}
		
		/**
		 * Ends the current session and clears local session state.
		 */
		public static function endSession(core:Core, callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			if (!hasSession(core)) {
				if (callback !== null) {
					callback.call(thisArg);
				}
				return;
			}
			
			var endSessionComponent:* = ObjectFactory.CreateComponent("App", "endSession", null, core);
			if (endSessionComponent == null) {
				throw new Error("Could not create App.endSession component");
			}
			core.executeComponent(endSessionComponent as io.newgrounds.BaseComponent, function(result:*):void {
				if (callback !== null) {
					callback.call(thisArg);
				}
			});
			
			core.appState.clearSession();
		}
		
		private static function hasSession(core:Core):Boolean {
			if (core.appState.session == null ||
				core.appState.session.id == null ||
				core.appState.session.id.length == 0 ||
				core.appState.session.expired === true) {
				return false;
			}
			return true;
		}
		
		private static function hasUser(core:Core):Boolean {
			return hasSession(core) && core.appState.session.user != null;
		}
	}
}
