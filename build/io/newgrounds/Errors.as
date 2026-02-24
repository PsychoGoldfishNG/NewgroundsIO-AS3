/**
 * Errors
 * 
 * Provides error codes and helper methods for generating Error models
 * 
 * This class centralizes error handling. Instead of scattered error codes throughout
 * the library, all error codes and messages are defined here. This makes it easy to:
 * - Look up what an error code means
 * - Create Error objects with consistent messages
 * - Catch specific errors by code
 * 
 * NOTE: This is a static class - all properties and methods are accessed at class level
 */
package io.newgrounds {
	
	import io.newgrounds.models.objects.ObjectFactory;
	
	public class Errors {
		
		//==================== ERROR CODE CONSTANTS ====================
		
		// Unknown error
		public static const UNKNOWN:int = 0;
		
		// Request-related errors
		public static const MISSING_REQUEST:int = 100;
		public static const INVALID_REQUEST:int = 101;
		public static const MISSING_PARAMETER:int = 102;
		public static const INVALID_PARAMETER:int = 103;
		
		// Session errors
		public static const EXPIRED_SESSION:int = 104;
		
		// Server-side limit errors
		public static const MAX_COMPONENTS_EXCEEDED:int = 107;
		public static const MEMORY_EXCEEDED:int = 108;
		public static const TIMED_OUT:int = 109;
		
		// Authentication errors
		public static const LOGIN_REQUIRED:int = 110;
		public static const CANCELLED_SESSION:int = 111;
		
		// App configuration errors
		public static const INVALID_APP_ID:int = 200;
		public static const INVALID_ENCRYPTION:int = 201;
		public static const INVALID_MEDAL_ID:int = 202;
		public static const INVALID_SCOREBOARD_ID:int = 203;
		public static const INVALID_SAVESLOT_ID:int = 204;
		
		// HTTP status code errors
		public static const BAD_REQUEST:int = 400;
		public static const USER_FORBIDDEN:int = 403;
		public static const NOT_FOUND:int = 404;
		public static const TOO_MANY_REQUESTS:int = 429;
		
		// Server-side problems
		public static const SERVER_ERROR:int = 500;
		public static const SERVER_UNAVAILABLE:int = 503;
		public static const GATEWAY_TIMEOUT:int = 504;
		public static const INVALID_RESPONSE:int = 505;
		
		//==================== ERROR MESSAGES ====================
		
		/**
		 * Maps error codes to human-readable error messages
		 * 
		 * Instead of numeric codes, users see helpful messages like
		 * "Your session has expired" or "You must be logged in to do that"
		 * 
		 * The key is the error CODE number, the value is the MESSAGE string
		 */
		private static const errorMessages:Object = {
			0: "An unknown error has occurred.",
			100: "Missing/empty request.",
			101: "Invalid request.",
			102: "Missing required parameter.",
			103: "Invalid parameter.",
			104: "Your session has expired.",
			107: "Maximum number of components, for a single request, has been exceeded. (Maximum is 10)",
			108: "Your request has exceeded the maximum allowed memory use on the server.",
			109: "Your request took too long to complete and timed out.",
			110: "You must be logged in to do that.",
			111: "Your session was cancelled on the server.",
			200: "Invalid App ID.",
			201: "An encrypted object failed to decrypt on the server. Make sure you are using the correct key, cypher, and encoding format.",
			202: "Requested Medal does not exist, or is not associated with this App ID.",
			203: "Requested ScoreBoard does not exist, or is not associated with this App ID.",
			204: "Requested SaveSlot does not exist, or is not associated with this App ID.",
			400: "There was a problem sending your request.",
			403: "Forbidden.",
			404: "Page not found.",
			429: "You are making too many requests.",
			500: "An unexpected error has occurred on the server. If error persists, contact support.",
			503: "The server is currently down, try again later.",
			504: "Unable to reach the server, try again later.",
			505: "Invalid response received from server."
		};
		
		//==================== PUBLIC STATIC METHODS ====================
		
		/**
		 * Look up the default error message for a specific error code
		 * 
		 * @param errorCode The error code to look up (defaults to UNKNOWN)
		 * @return A human-readable error message string
		 * 
		 * Always returns a string, never null
		 * If code doesn't exist, falls back to UNKNOWN message
		 */
		public static function getDefaultMessage(errorCode:int = 0):String {
			// Look up the error code in the messages dictionary
			if (errorMessages.hasOwnProperty(errorCode)) {
				// Found it - return the message
				return errorMessages[errorCode] as String;
			} else {
				// Unknown code - return generic unknown message
				return errorMessages[0] as String;
			}
		}
		
		/**
		 * Create an Error model with a specified code and custom message
		 * 
		 * @param errorCode The error code (defaults to UNKNOWN)
		 * @param errorMessage A custom message providing extra details
		 * @param appendMessage If true, add the custom message to the default message
		 * @return A new Error model instance with code and message set
		 * 
		 * This method creates an Error object with three possible message formats:
		 * 1. Just the default message for the error code
		 * 2. Just the custom message (if provided and appendMessage=false)
		 * 3. Default message + custom message (if appendMessage=true)
		 * 
		 * Example: If EXPIRED_SESSION message is "Your session has expired." and
		 * developer provides custom message "Attempt was made at 3:45 PM", result could be:
		 * - appendMessage=false: "Attempt was made at 3:45 PM"
		 * - appendMessage=true: "Your session has expired. Attempt was made at 3:45 PM"
		 */
		public static function getError(errorCode:int = 0, 
		                                errorMessage:String = null, 
		                                appendMessage:Boolean = false):* {
			// Create a new NgioError model using ObjectFactory
			var errorModel:io.newgrounds.models.objects.NgioError = ObjectFactory.CreateObject("Error") as io.newgrounds.models.objects.NgioError;
			
			// Set the error code
			errorModel.code = errorCode;
			
			// Handle the message
			if (errorMessage == null || errorMessage.length == 0) {
				// No custom message provided - use the default
				errorMessage = getDefaultMessage(errorCode);
				appendMessage = false;
			}
			
			// Optionally append custom message to default message
			if (appendMessage) {
				// Get the default message for this code
				var defaultMessage:String = getDefaultMessage(errorCode);
				// Combine them: default first, then custom
				errorMessage = defaultMessage + " " + errorMessage;
			}
			
			// Set the final message on the error model
			errorModel.message = errorMessage;
			
			return errorModel;
		}
	}
}
