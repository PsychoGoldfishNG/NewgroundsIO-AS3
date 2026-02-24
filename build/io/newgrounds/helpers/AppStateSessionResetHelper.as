package io.newgrounds.helpers {
	
	import io.newgrounds.AppState;
	
	/**
	 * AppStateSessionResetHelper
	 *
	 * Clears session-scoped data from AppState-owned objects when session is invalidated.
	 */
	public class AppStateSessionResetHelper {
		
		/**
		 * Clears session-specific fields from session/save slot/medal state.
		 */
		public static function clearSessionScopedData(appState:AppState):void {
			if (appState.session != null && appState.session.hasOwnProperty("clearSessionData")) {
				appState.session.clearSessionData();
			}
			
			if (appState.saveSlots != null) {
				for each (var saveSlot:* in appState.saveSlots) {
					if (saveSlot.hasOwnProperty("clearSessionData")) {
						saveSlot.clearSessionData();
					}
				}
			}
			
			if (appState.medals != null) {
				for each (var medal:* in appState.medals) {
					if (medal.hasOwnProperty("clearSessionData")) {
						medal.clearSessionData();
					}
				}
			}
			
			appState.medalScore = 0;
			appState.passportIsOpen = false;
		}
	}
}
