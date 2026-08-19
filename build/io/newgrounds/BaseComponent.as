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

	import io.newgrounds.models.objects.NgioError;

	public class BaseComponent extends BaseObject {
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * Whether this component must be encrypted before sending
		 * Sensitive operations like unlocking medals or posting scores are encrypted
		 * to prevent hackers from cheating
		 */
		public var isSecure:Boolean = false;
		
		/**
		 * Whether a session ID must be present in the request envelope
		 *
		 * From the schema's `require_session`, which means literally that: an id
		 * has to be sent. It says nothing about whether anyone is signed in -
		 * that is `requiresLogin` below.
		 */
		public var requiresSession:Boolean = false;

		/**
		 * Whether a VALIDATED LOGIN is required, not merely a session id
		 *
		 * From the schema's `require_login`. A guest session has a real id
		 * belonging to nobody: it satisfies requiresSession, and the gateway
		 * still refuses these with 110.
		 *
		 * NOT a parameter. This does not mean "pass a user object" - it is why
		 * the flag is `require_login` rather than `require_user`, which read like
		 * an argument the caller had to supply.
		 *
		 * Absent from the schema means false, so a component is only gated once
		 * the gateway says so. Never infer it from requiresSession.
		 */
		public var requiresLogin:Boolean = false;
		
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
			this.requiresLogin = false;
			this.redirect = false;
			this.browserTarget = null;
		}
		
		//==================== OVERRIDDEN METHODS ====================
		
		/**
		 * Enhanced validation that includes session requirements
		 * Components have special validation - they might require a logged-in user
		 *
		 * Core consults this before sending, so a component that cannot possibly
		 * succeed is refused here instead of costing a round trip. The codes
		 * match what the gateway returns for the same conditions - confirmed
		 * live - so callers cannot tell a local refusal from a server one except
		 * by how fast it arrives:
		 *
		 *   102 MISSING_PARAMETER  no session id to send
		 *   110 LOGIN_REQUIRED     a session, but nobody signed in (guest)
		 *
		 * TWO FLAGS, AND THEY ARE NOT THE SAME QUESTION:
		 *
		 *   requiresSession (schema: require_session)
		 *       A session id must be in the envelope. Literally that, and
		 *       nothing more.
		 *
		 *   requiresLogin (schema: require_login)
		 *       A validated login is required. A guest session - a real id
		 *       belonging to nobody - satisfies requiresSession and fails this.
		 *
		 * WHY BOTH EXIST, and it is worth knowing because the old shape looked
		 * reasonable: the gateway has always checked these two things separately
		 * and correctly. THE SCHEMA was what conflated them - a single
		 * `require_session` flag was used where `require_login` is used now, so
		 * the one flag carried both meanings and nothing could tell them apart.
		 *
		 * This library read that flag as "needs a logged-in user" and demanded
		 * session.user, which matched what the flag then meant. Nothing ever
		 * called the method, so it cost nothing - but wiring it into the send
		 * path unchanged WOULD HAVE MADE SIGN-IN IMPOSSIBLE, because
		 * App.checkSession was marked with it despite needing no login at all.
		 * Its entire job is to find out whether someone has signed in yet.
		 *
		 * The schema now says the two things separately, so this method can too.
		 *
		 * A component with no require_login in the schema gets false, so nothing
		 * is gated until the gateway says it should be. Never re-derive this from
		 * requiresSession.
		 *
		 * @return An NgioError describing the first problem found, or null
		 */
		override public function getPreflightError():io.newgrounds.models.objects.NgioError {
			// ==================== RUN PARENT VALIDATION ====================
			// Check all the basic required properties first
			var parentError:io.newgrounds.models.objects.NgioError = super.getPreflightError();
			if (parentError != null) {
				// Parent validation failed - this component is incomplete
				return parentError;
			}

			// ==================== CHECK SESSION REQUIREMENT ====================
			if (this.requiresSession) {
				// This component needs a session id in the envelope. Anything
				// below means there is no id to send, so the gateway would
				// answer 102 - and it can answer that without being asked.

				// First check if core is available
				if (this.core == null) {
					// No core reference - can't check session
					return sessionError(Errors.MISSING_PARAMETER, "has no Core to read a session from");
				}

				// Check if appState is available
				if (this.core.appState == null) {
					// No app state - can't check session
					return sessionError(Errors.MISSING_PARAMETER, "has no app state to read a session from");
				}

				// Get the current session from app state
				var session:* = this.core.appState.session;

				// Validate the session exists
				if (session == null) {
					// No session at all - can't execute
					return sessionError(Errors.MISSING_PARAMETER, "requires a session, and there is none");
				}

				// Validate that session has an ID.
				//
				// A session id with no user attached is a GUEST session, which
				// satisfies require_session. Whether it is ENOUGH is
				// require_login's question, not this one's.
				if (session.id == null || (session.id is String && (session.id as String).length == 0)) {
					// No session token - can't execute
					return sessionError(Errors.MISSING_PARAMETER, "requires a session id, and the session has none");
				}
			}

			// ==================== CHECK LOGIN REQUIREMENT ====================
			//
			// Deliberately independent of requiresSession above rather than
			// nested inside it. A component needing a login needs a session id by
			// definition, but reading that dependency out of the schema is the
			// gateway's job, not an inference to make here - and if a component
			// ever carries require_login without require_session, the honest
			// answer is still "you are not logged in".
			if (this.requiresLogin) {
				if (this.core == null || this.core.appState == null) {
					return sessionError(Errors.LOGIN_REQUIRED, "requires a logged-in user, and there is no app state to read a session from");
				}

				var loginSession:* = this.core.appState.session;

				if (loginSession == null || loginSession.user == null) {
					// Either no session at all, or a GUEST session - the id is
					// real and belongs to nobody. The gateway answers 110 here.
					return sessionError(Errors.LOGIN_REQUIRED, "requires a logged-in user, and this session has none");
				}

				if (loginSession.user.id == null ||
				    (loginSession.user.id is String && (loginSession.user.id as String).length == 0)) {
					// User object exists but carries no id - not a state the
					// gateway can act on either.
					return sessionError(Errors.LOGIN_REQUIRED, "requires a logged-in user, and this session's user has no id");
				}
			}

			// ==================== ALL VALIDATION PASSED ====================
			// Component is properly formatted and can be executed
			return null;
		}

		/**
		 * Builds a session-requirement error naming this component.
		 */
		protected function sessionError(code:int, problem:String):io.newgrounds.models.objects.NgioError {
			return Errors.getError(
				code,
				getFullObjectName() + " " + problem + ".",
				false
			) as io.newgrounds.models.objects.NgioError;
		}
	}
}
