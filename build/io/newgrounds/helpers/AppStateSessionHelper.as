package io.newgrounds.helpers {
	
	import io.newgrounds.AppState;
	import io.newgrounds.Errors;
	import io.newgrounds.SessionStatus;
	
	/**
	 * AppStateSessionHelper
	 *
	 * Derives SessionStatus from AppState session fields.
	 */
	public class AppStateSessionHelper {
		
		/**
		 * Builds a SessionStatus snapshot from current AppState data.
		 */
		public static function getSessionStatus(appState:AppState, onSessionCleared:Function = null):SessionStatus {
			var sessionStatus:SessionStatus = new SessionStatus();
			
			if (appState.session == null || appState.session.id == null || appState.session.id.length == 0) {
				return sessionStatus;
			}
			
			if (appState.session.expired === true) {
				if (onSessionCleared != null) {
					onSessionCleared.call();
				}
				sessionStatus.status = SessionStatus.EXPIRED;
				return sessionStatus;
			}
			
			if (appState.session.error != null) {
				if (appState.session.error.code == Errors.CANCELLED_SESSION) {
					if (onSessionCleared != null) {
						onSessionCleared.call();
					}
					sessionStatus.status = SessionStatus.LOGIN_CANCELLED;
				} else {
					sessionStatus.status = SessionStatus.ERROR;
					sessionStatus.error = appState.session.error;
				}
				return sessionStatus;
			}
			
			if (appState.session.user != null) {
				sessionStatus.user = appState.session.user;
				sessionStatus.status = SessionStatus.LOGGED_IN;
				return sessionStatus;
			}
			
			if (appState.session.isPreauthenticated()) {
				sessionStatus.status = SessionStatus.SESSION_ID_PROVIDED;
				return sessionStatus;
			}
			
			if (appState.session.passport_url == null || appState.session.passport_url.length == 0) {
				sessionStatus.status = SessionStatus.UNVERIFIED;
				return sessionStatus;
			}
			
			if (appState.passportIsOpen === true) {
				sessionStatus.status = SessionStatus.WAITING_FOR_PASSPORT;
				return sessionStatus;
			}
			
			sessionStatus.status = SessionStatus.NOT_LOGGED_IN;
			return sessionStatus;
		}
	}
}
