/**
 * SessionStatus
 * 
 * Represents the current status of a client session (result of checkSession call)
 * 
 * This class is the result/response object returned by NGIO.checkSession().
 * It provides a simple, easy-to-understand snapshot of the session state.
 * 
 * WHY SEPARATE?: The actual Session object is complex and tracks many properties.
 * SessionStatus simplifies this into just three properties and a status code, making
 * it much easier for developers to understand the session state at a glance.
 * 
 * RELATIONSHIP: SessionStatus is a SNAPSHOT of the session at one moment in time.
 * It doesn't track changes - it's just what the status WAS when you called checkSession().
 * The actual session data is in NGIO.appState.session (a Session object).
 * 
 * NOTE: This is a simple data model that does NOT extend BaseObject
 */
package io.newgrounds {
	
	public class SessionStatus {
		
		//==================== STATUS CONSTANTS ====================
		
		/**
		 * No session exists yet
		 * Initial state when app first loads
		 * WHAT TO DO: Call NGIO.checkSession() to create a session
		 */
		public static const UNINITIALIZED:String = "uninitialized";
		
		/**
		 * Session exists but hasn't been verified with the server yet
		 * We have a session ID but haven't received verification from the server yet
		 * WHAT TO DO: Call NGIO.checkSession() to verify with the server, or wait for pending request
		 */
		public static const UNVERIFIED:String = "unverified";
		
        /**
         * Session ID was provided in URL but hasn't been validated yet
         * A session ID was passed via URL parameters (like from Newgrounds.com embed)
         * but we haven't verified it with the server yet
         * WHAT TO DO: Call NGIO.checkSession() to validate the session ID
         */
        public static const SESSION_ID_PROVIDED:String = "session-id-provided";
        

		/**
		 * Session is valid but no user is logged in (guest session)
		 * User hasn't used the login feature yet
		 * WHAT TO DO: Call NGIO.openPassport() to open the login window
		 */
		public static const NOT_LOGGED_IN:String = "not-logged-in";
		
		/**
		 * Login window is open, waiting for user to log in
		 * Passport window was opened but user hasn't finished logging in
		 * WHAT TO DO: Wait for user to finish. Call NGIO.checkSession() intermittently to see if status changed
		 */
		public static const WAITING_FOR_PASSPORT:String = "waiting-for-passport";
		
		/**
		 * User is fully logged in
		 * Session is valid AND user has authenticated
		 * WHAT TO DO: You're good to go! Proceed with gameplay
		 */
		public static const LOGGED_IN:String = "logged-in";
		
		/**
		 * User clicked "cancel" on the login form
		 * User started the login process but changed their mind
		 * WHAT TO DO: Session is destroyed. You can call NGIO.checkSession() to start a new one
		 */
		public static const LOGIN_CANCELLED:String = "login-cancelled";
		
		/**
		 * The session ID has expired on the server
		 * Sessions expire after inactivity (hours to days depending on settings)
		 * WHAT TO DO: Get a new session by calling NGIO.checkSession()
		 */
		public static const EXPIRED:String = "expired";
		
		/**
		 * Something went wrong
		 * Network error, server error, invalid app ID, etc.
		 * WHAT TO DO: Check the error property for details. Might be temporary.
		 */
		public static const ERROR:String = "error";
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * The current session status
		 * 
		 * Tells the developer what state the session is in
		 * Must be one of the status constants above
		 * Check this value in an if/switch statement to decide what to do next
		 */
		public var status:String = UNINITIALIZED;
		
		/**
		 * The logged-in user (if status = LOGGED_IN), otherwise null
		 * 
		 * Provides user info when needed
		 * Contents when set: { id, name, supporter, url }
		 * When null: In all other statuses (not logged in, error, etc.)
		 */
		public var user:* = null;
		
		/**
		 * Error details (if status = ERROR), otherwise null
		 * 
		 * Helps developer understand what went wrong
		 * Contents when set: { code, message }
		 * Code values match io.newgrounds.Errors constants
		 * When null: In success states (LOGGED_IN) and transient states
		 */
		public var error:* = null;
		
		//==================== CONSTRUCTOR ====================
		
		public function SessionStatus() {
			// Set initial values - uninitialized with no user or error
			this.status = SessionStatus.UNINITIALIZED;
			this.user = null;
			this.error = null;
		}
		
		//==================== IMPORTANT NOTES ====================
		
		// This object is READ-ONLY. Don't modify its properties after creation.
		// It's a snapshot - creating a new SessionStatus won't affect the real session.
		//
		// The real session data is in: NGIO.appState.session (Session object)
		// This is just: A simplified status report for easy understanding
	}
}
