/**
 * BaseComponent
 * 
 * Base class for all component models sent to servers
 * 
 * Components are the building blocks of API calls. Every action you send to
 * the server (unlock a medal, post a score, check session, etc.) is done via a component.
 * This base class provides common functionality for all component types.
 * 
 * KEY CONCEPT: Components are OUTGOING - sent FROM the app TO the server.
 * (Results are the INCOMING response FROM server TO app)
 */
package io.newgrounds {
	
	public class BaseComponent extends BaseObject {
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * Whether this component must be encrypted before sending
		 * Sensitive operations like unlocking medals or posting scores are encrypted
		 * to prevent hackers from cheating
		 */
		public var isSecure:Boolean = false;
		
		/**
		 * Whether the user must be logged in to execute this component
		 * Some actions are only available to authenticated users
		 */
		public var requiresSession:Boolean = false;
		
		/**
		 * Whether this component opens a browser window (Passport login)
		 * Instead of making AJAX request with JSON, the browser is redirected
		 */
		public var redirect:Boolean = false;
		
		/**
		 * The window/frame to open redirect in (if redirect=true)
		 * Values: "_blank" (new window), "_self" (current), "_parent", "_top"
		 */
		public var browserTarget:String = null;
		
		//==================== CONSTRUCTOR ====================
		
		public function BaseComponent() {
			// Call parent constructor
			super();
			
			// Set component-specific defaults
			this.isSecure = false;
			this.requiresSession = false;
			this.redirect = false;
			this.browserTarget = null;
		}
		
		//==================== OVERRIDDEN METHODS ====================
		
		/**
		 * Enhanced validation that includes session requirements
		 * Components have special validation - they might require a logged-in user
		 * 
		 * @return true if valid, false if any validation fails
		 */
		override public function hasValidProperties():Boolean {
			// ==================== RUN PARENT VALIDATION ====================
			// Check all the basic required properties first
			var parentIsValid:Boolean = super.hasValidProperties();
			if (!parentIsValid) {
				// Parent validation failed - this component is incomplete
				return false;
			}
			
			// ==================== CHECK SESSION REQUIREMENT ====================
			if (this.requiresSession) {
				// This component requires the user to be logged in
				// Check if we have a valid authenticated session
				
				// First check if core is available
				if (this.core == null) {
					// No core reference - can't check session
					return false;
				}
				
				// Check if appState is available
				if (this.core.appState == null) {
					// No app state - can't check session
					return false;
				}
				
				// Get the current session from app state
				var session:* = this.core.appState.session;
				
				// Validate the session exists
				if (session == null) {
					// No session at all - can't execute
					return false;
				}
				
				// Validate that session has an ID
				if (session.id == null || (session.id is String && (session.id as String).length == 0)) {
					// No session token - can't execute
					return false;
				}
				
				// Validate that a user is logged in
				if (session.user == null) {
					// Session exists but no user logged in - can't execute
					return false;
				}
				
				// Validate that user has an ID
				if (session.user.id == null || 
				    (session.user.id is String && (session.user.id as String).length == 0)) {
					// User exists but has no ID - invalid state
					return false;
				}
			}
			
			// ==================== ALL VALIDATION PASSED ====================
			// Component is properly formatted and can be executed
			return true;
		}
	}
}
