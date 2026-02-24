/**
 * BaseResult
 * 
 * Base class for all component result models received from server
 * 
 * When you send a component to the server, the server sends back a result.
 * This base class provides the common structure for all result objects.
 * 
 * KEY CONCEPT: Results are INCOMING - received FROM the server.
 * Components are the REQUEST. Results are the RESPONSE.
 * 
 * RESULT PATTERN:
 * Every component produces a result:
 * - Medal.unlock component -> Medal.unlockResult
 * - Score.postScore component -> Score.postScoreResult
 * - CheckSession component -> CheckSessionResult
 * 
 * All results extend BaseResult and contain:
 * 1. Success flag (did it work?)
 * 2. Error object (if it failed)
 * 3. Component-specific response data
 */
package io.newgrounds {
	
	
	public class BaseResult extends BaseObject {
		
		//==================== PUBLIC PROPERTIES ====================
		
		/**
		 * Whether the component execution succeeded
		 * 
		 * The server ALWAYS sets this - check it first before accessing data
		 * - true: Component executed successfully
		 * - false: Component failed (check error property for why)
		 */
		public var success:Boolean = false;
		
		//==================== CONSTRUCTOR ====================
		
		public function BaseResult() {
			// Call parent constructor
			super();
			
			// Set default values
			// Most results start with success=false
			// (These will be overwritten when imported from server response)
			this.success = false;
		}
		
        //==================== OVERRIDDEN METHODS ====================
        /**
        * Override importFromObject to inject success
        */
        override public function importFromObject(importObject:*):void {
            super.importFromObject(importObject);
            // Import success property if it exists
            if (importObject.hasOwnProperty("success")) {
                this.success = importObject.success as Boolean;
            }
        }

		//==================== USAGE PATTERN ====================
		
		// Typical usage in developer code:
		//
		// NGIO.core.queueComponent(medalComponent);
		// NGIO.core.executeQueue(function(response:Response):void {
		//     // response is a Response object containing an array of results
		//     if (response == null) {
		//         // Network error
		//         showError("Network error");
		//         return;
		//     }
		//
		//     // Loop through the results
		//     for each (var result:* in response.results) {
		//         if (result.success) {
		//             // Component succeeded - result contains component-specific data
		//             if (result is MedalUnlockResult) {
		//                 showNotification("Medal unlocked: " + result.medal.name);
		//                 updateScoreDisplay(result.medalScore);
		//             }
		//         } else {
		//             // Component failed - result.error explains why
		//             showError("Failed: " + result.error.message);
		//         }
		//     }
		// });
		
		//==================== IMPORTANT NOTES ====================
		
		// Always Check Success:
		//   Never assume a component succeeded. Always check:
		//   if (result.success) {
		//       // Safe to use component-specific properties
		//   } else {
		//       // Use result.error for error details
		//   }
		//
		// Error Handling:
		//   If success=false, result.error is guaranteed to exist
		//   - result.error.code: Numeric error code
		//   - result.error.message: Human-readable message
		//
		// Component-Specific Data:
		//   The specific properties in a result depend on the component
		//   Refer to component documentation for what properties are available
		//   Example: Medal.unlockResult will have medal and medalScore,
		//   but Score.postScoreResult might have different properties
		//
		// Server Authority:
		//   The server is the authority. The values in the result represent
		//   the server's state, not what you sent. For example:
		//   - You might request unlocking medal ID 5
		//   - Server returns updated medal object with current unlock status
		//   - Medal might already have been unlocked (no change in result)
		//
		// Immutable Results:
		//   Results from the server shouldn't be modified by application code
		//   They represent a snapshot of server state at a moment in time
		//   If you want to change something, send another component
		//   Don't directly modify result properties
	}
}
