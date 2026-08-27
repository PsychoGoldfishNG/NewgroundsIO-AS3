

/**
 * Request
 * 
 * A top-level wrapper containing any information needed to authenticate the application/user and any component calls being made.
 */
package io.newgrounds.models.objects {
	
	import io.newgrounds.BaseObject;
	
	public class Request extends BaseObject {
		
		//==================== PROPERTIES ====================
		
		/**
		 * Your application's unique ID.
		 */
		public var app_id:String = null;
		
		/**
		 * An optional login session id. Components that save and unlock things to a user account will require this.
		 */
		public var session_id:String = null;
		
		/**
		 * If set to true, calls will be executed in debug mode.
		 */
		public var debug:Boolean = false;
		
		/**
		 * An optional value that will be returned, verbatim, in the #Response object.
		 */
		public var echo:* = null;
		
		/**
		 * A #Execute object, or array of one-or-more #Execute objects.
		 *
		 * Excluded from the schema-driven propertyNames loop (see object.ejs) because
		 * this is Model-Generation.md's Mixed Type Handling pattern - use
		 * setExecute()/setExecuteList()/executeIsList() rather than assigning directly.
		 */
		public var execute:* = null;

		/**
		 * Array of Execute objects (for mixed type handling with single execute)
		 */
		public var executeList:Array;
		
		//==================== CONSTRUCTOR ====================
		
		public function Request() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Request";
		}
		
		/**
		 * Object type identifier
		 */
		override public function get objectType():String {
			return "object";
		}
		
		/**
		 * All property names for this object
		 */
		override public function get propertyNames():Array {
			return ["app_id","session_id","debug","echo"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			return ["app_id"];
		}
		
		/**
		 * Type casting map for deserializing properties
		 */
		override public function get castTypes():Object {
			return {
			};
		}
		
		//==================== CUSTOM METHODS ====================
		/**
		 * Sets a single Execute object and clears the list
		 * 
		 * @param executeObject A single Execute instance
		 */
		public function setExecute(executeObject:*):void {
			this.execute = executeObject;
			this.executeList = null;
		}
		
		/**
		 * Sets an array of Execute objects and clears the single value
		 * 
		 * @param executeArray An array of Execute instances
		 */
		public function setExecuteList(executeArray:Array):void {
			this.executeList = executeArray;
			this.execute = null;
		}
		
		/**
		 * Checks if execute is in list format
		 *
		 * @return true if using list format, false if using single value
		 */
		public function executeIsList():Boolean {
			return this.executeList != null && this.executeList.length > 0;
		}
		
		/**
		 * Gets the single Execute object
		 * 
		 * @return Single Execute instance or null
		 */
		public function getExecute():* {
			return this.execute;
		}
		
		/**
		 * Gets the Execute objects array
		 * 
		 * @return Array of Execute instances or null
		 */
		public function getExecuteList():Array {
			return this.executeList;
		}	}
}
