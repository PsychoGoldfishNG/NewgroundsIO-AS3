/**
 * BaseObject
 * 
 * Foundation class for all model objects with serialization/deserialization
 * 
 * Every model in Newgrounds.io (User, Medal, Score, SaveSlot, etc.) extends BaseObject.
 * BaseObject provides essential functionality that all models need:
 * - Importing data from JSON
 * - Type casting (converting raw values to proper types)
 * - Validating required properties
 * - Converting back to JSON strings
 * - Name tracking for nested objects
 */
package io.newgrounds {
	
    import io.newgrounds.Core;
    import io.newgrounds.NGJSON;
    import io.newgrounds.models.objects.ObjectFactory;

	public class BaseObject {
		
		//==================== ABSTRACT PROPERTIES ====================
		// These must be overridden in each subclass
		
		/**
		 * The name of this object type for the JSON (e.g., "User", "Medal", "Score")
		 * Used when serializing to JSON to indicate what type of object this is
		 */
		public function get objectName():String {
			throw new Error("BaseObject.objectName must be overridden in subclass");
		}
		
		/**
		 * A category/namespace for this object (e.g., "object", "component", "result")
		 * Used to create the full qualified name like "object.User" or "component.Medal.unlock"
		 */
		public function get objectType():String {
			throw new Error("BaseObject.objectType must be overridden in subclass");
		}
		
		/**
		 * List of all property names this object supports
		 * Prevents typos - only properties in this list can be imported
		 */
		public function get propertyNames():Array {
			throw new Error("BaseObject.propertyNames must be overridden in subclass");
		}
		
		/**
		 * List of properties that MUST be present
		 * Some properties are critical - if missing, the object is incomplete/invalid
		 */
		public function get requiredProperties():Array {
			throw new Error("BaseObject.requiredProperties must be overridden in subclass");
		}
		
		/**
		 * Specifies how to cast (convert) each property value to the correct type
		 * Values can be: 'string', 'number', 'boolean', ClassName, or 'array-of-ClassName'
		 */
		public function get castTypes():Object {
			throw new Error("BaseObject.castTypes must be overridden in subclass");
		}
		
		//==================== PUBLIC PROPERTIES ====================
		
		/** Reference to the Core instance for accessing app state and executing components */
		public var core:Core;
		
		/** Parent object if this is nested (used for hierarchical naming) */
		public var parent:BaseObject;
		
		/** Property name in parent object (used for hierarchical naming) */
		public var parentPropertyName:String;
	
        /** Error details if something went wrong (can be set on any object) */
        public var error:io.newgrounds.models.objects.NgioError = null;

        /** Static counter for tracking object IDs (for debugging) */
        private static var objectIDTracking:Number = 0;

        /** Unique object ID assigned during construction (for debugging) */
        public var objectId:Number = -1;

        //==================== ABSTRACT METHODS ====================
        
        /**
	 * Helper method to get a class by its name
	 * Override this in subclasses if you need custom class resolution
	 * 
	 * @param className The name of the class to resolve
	 * @return The Class object, or null if not found
	 */
	protected function getClassByName(className:String):Class {
		// This is a placeholder - subclasses or a factory should implement proper class resolution
		// For now, return null and expect subclasses to override castToExpectedType for complex types
		return null;
	}

        //==================== PUBLIC METHODS ====================

        /**
         * Constructor for BaseObject
         * Initializes the object and assigns a unique objectId for debugging
         */
        public function BaseObject() {
            this.objectId = BaseObject.objectIDTracking++;
        }

        /**
		 * Import data from a plain object (usually JSON parsed from server)
		 * Converts plain JSON format to properly-typed model objects with all properties set correctly
		 * 
		 * @param importObject Plain object with raw data (e.g., from JSON.parse)
		 */
		public function importFromObject(importObject:*):void {
			// ==================== VALIDATE INPUT ====================
			if (importObject == null || importObject == undefined) {
				// Nothing to import
				return;
			}

            // ==================== HANDLE BASEOBJECT IMPORT ====================
			// If importing from another BaseObject instance
			if (importObject is BaseObject) {
            	// Verify same type
				if ((importObject as BaseObject).getFullObjectName() != this.getFullObjectName()) {
					throw new Error("Cannot import " + (importObject as BaseObject).getFullObjectName() + 
					               " into " + this.getFullObjectName());
				}
				// Convert to plain object first
				importObject = (importObject as BaseObject).toObject(false, false);
			}
			
			// Verify it's a simple object (not array, not primitive)
			if (importObject is Array || !(importObject is Object)) {
				throw new Error("importObject must be a plain object or BaseObject instance");
			}
			
			// ==================== IMPORT EACH PROPERTY ====================
			var propNames:Array = propertyNames;
			var castTypesObj:Object = castTypes;

			for (var i:int = 0; i < propNames.length; i++) {
				var propertyName:String = propNames[i] as String;
				
				// Check if property exists in the import object
				if (!(propertyName in importObject)) {
					// Property not provided - keep existing value
                    continue;
				}
				
				var propertyValue:* = importObject[propertyName];
				
				// === STANDARD CAST AND ASSIGN ===
				var castValue:* = castToExpectedType(propertyName, propertyValue);
				this[propertyName] = castValue;		
			}

            // ==================== CHECK FOR ERROR PROPERTY ====================
            // If the import object contains an error property, create an NgioError model
            if ("error" in importObject && importObject.error != null) {
                // Create a new NgioError object using the factory
                this.error = ObjectFactory.CreateObject("Error", importObject.error, this.core) as io.newgrounds.models.objects.NgioError;
            }
            
		}
		
		/**
		 * Convert a property value to its correct type
		 * JSON only has strings, numbers, booleans, arrays, and objects. We need to
		 * convert these raw values to the correct model types
		 * 
		 * @param propertyName Name of the property being cast (used to look up type info)
		 * @param value The raw value from JSON
		 * @return The value converted to the correct type
		 */
		protected function castToExpectedType(propertyName:String, value:*):* {
			// If value is null or undefined, keep it null
			if (value == null || value == undefined) {
				return null;
			}
			
			// Look up the type for this property
			var castTypesObj:Object = castTypes;
			if (!(propertyName in castTypesObj)) {
				// No type specified - keep as-is
				return value;
			}
			
			var castType:* = castTypesObj[propertyName];

			// ==================== HANDLE PRIMITIVES ====================
			if (castType == 'string') {
				return String(value);
			} else if (castType == 'number') {
				return Number(value);
			} else if (castType == 'boolean') {
				if (value is String) {
					return (value as String).toLowerCase() == 'true';
				} else {
					return Boolean(value);
				}
			}
			
			// ==================== HANDLE ARRAYS ====================
			// Check for array-of-X pattern (e.g., "array-of-Medal")
			if (castType is String && (castType as String).indexOf('array-of-') == 0) {
                // Extract the item type from "array-of-ClassName"
                var itemType:String = (castType as String).substring(9); // Remove "array-of-" prefix
                
                // Handle both single item and array cases
                var resultArray:Array = [];
                
                if (value is Array) {
                    // Value is already an array - convert each element
                    var valueArray:Array = value as Array;
                    for (var j:int = 0; j < valueArray.length; j++) {
                        var element:* = valueArray[j];
                        if (element is Object && !(element is Array)) {
                            // Convert plain object to typed object using factory
                            element = ObjectFactory.CreateObject(itemType, element, this.core);
                        }
                        resultArray.push(element);
                    }
                } else if (value is Object) {
                    // Value is a single object - convert and wrap in array
                    return [ObjectFactory.CreateObject(itemType, value, this.core)];
                } else {
                    // Value is neither array nor object - return empty array
                    return [];
                }
                
                return resultArray;
			}
			
			// ==================== HANDLE SINGLE OBJECTS ====================
			// castType is an object model class name (e.g., User, Medal, etc.)
			// value should be a plain object that we'll convert to castType
			
			if (value is Object && !(value is Array) && castType !== "Array") {
				return ObjectFactory.CreateObject(castType, value, this.core);
			}
			
			// Value isn't the right format - return as-is
			return value;
		}
		
		/**
		 * Returns the fully-qualified name of this object for logging/debugging
		 * Helps track nested objects.
		 * 
		 * @return Qualified name like "object.User" or "component.Medal.unlock"
		 */
		public function getFullObjectName():String {
			// Start with objectType and objectName
			var fullName:String = objectType + "." + objectName;
			
			// If this object is nested inside another, include parent
			if (parent != null && parentPropertyName != null) {
				fullName = parent.getFullObjectName() + "." + parentPropertyName;
			}
			
			return fullName;
		}
		
		/**
		 * Check if this object has all required properties
		 * Objects from the server might be incomplete. We validate before using them.
		 * 
		 * @return true if all required properties are present, false if any are missing
		 */
		public function hasValidProperties():Boolean {
			var reqProps:Array = requiredProperties;
			
			// Check each required property
			for (var i:int = 0; i < reqProps.length; i++) {
				var requiredProperty:String = reqProps[i] as String;
				
				if (this[requiredProperty] == null || this[requiredProperty] == undefined) {
					// Missing a required property!
					return false;
				}
				
				// Check for empty strings
				if (this[requiredProperty] is String) {
					if ((this[requiredProperty] as String).length == 0) {
						return false;
					}
				}
				
				// Check for empty arrays
				if (this[requiredProperty] is Array) {
					if ((this[requiredProperty] as Array).length == 0) {
						return false;
					}
				}
				
				// Note: The number 0 and boolean false are considered valid values
			}
			
			// All required properties are present and valid
			return true;
		}
		
		/**
		 * Get a list of all validation errors
		 * Provides detailed error information instead of just true/false
		 * 
		 * @return Array of error message strings (empty array if no errors)
		 */
		public function getValidationErrors():Array {
			var errors:Array = [];
			var reqProps:Array = requiredProperties;
			
			// Check each required property
			for (var i:int = 0; i < reqProps.length; i++) {
				var requiredProperty:String = reqProps[i] as String;
				
				if (this[requiredProperty] == null || this[requiredProperty] == undefined) {
					// Add error message for missing property
					errors.push("Required property '" + requiredProperty + "' is missing or null");
					continue;
				}
				
				// Check for empty strings
				if (this[requiredProperty] is String) {
					if ((this[requiredProperty] as String).length == 0) {
						errors.push("Required property '" + requiredProperty + "' is an empty string");
						continue;
					}
				}
				
				// Check for empty arrays
				if (this[requiredProperty] is Array) {
					if ((this[requiredProperty] as Array).length == 0) {
						errors.push("Required property '" + requiredProperty + "' is an empty array");
						continue;
					}
				}
				
				// Note: The number 0 and boolean false are considered valid values
			}
			
			return errors;
		}
		
		/**
		 * Convert this model object to a plain object for serialization
		 * When sending data to the server, we need plain objects (not model instances)
		 * so they can be JSON.stringify'd
		 * 
		 * @param recursive If true, convert nested objects too. If false, only this level.
		 * @param excludeNulls If true, don't include properties with null values.
		 * @return Plain object ready for JSON serialization
		 */
		public function toObject(recursive:Boolean = true, excludeNulls:Boolean = true):Object {
			// Create a plain object to hold the data
			var result:Object = {};
			var propNames:Array = propertyNames;
			
			// Copy each property that's in propertyNames
			for (var i:int = 0; i < propNames.length; i++) {
				var propertyName:String = propNames[i] as String;
				var value:* = this[propertyName];
				
				// Check if we should exclude this property
				if (excludeNulls && value == null) {
					// Skip null properties
					continue;
				}
				
				// If recursive, convert nested objects to plain objects too
				if (recursive && value is BaseObject) {
					// It's a model object - convert it recursively
					value = (value as BaseObject).toObject(recursive, excludeNulls);
				} else if (recursive && value is Array) {
					// It's an array - recursively convert each element
					var newArray:Array = [];
					var valueArray:Array = value as Array;
					for (var j:int = 0; j < valueArray.length; j++) {
						var element:* = valueArray[j];
						if (element is BaseObject) {
							newArray.push((element as BaseObject).toObject(recursive, excludeNulls));
						} else {
							newArray.push(element);
						}
					}
					value = newArray;
				}
				
				// Add to result object
				result[propertyName] = value;
			}
			
			return result;
		}
		
		/**
		 * Convert this object to a JSON-serializable Object
		 * Returns a plain Object representation of this model
		 * 
		 * @return Object representation of this object
		 */
		public function toJSON():Object {
			return prepareForJson();
		}
		
		/**
		 * Convert this object to a JSON string
		 * Quick way to serialize for transmission or storage
		 * 
		 * @return JSON string representation of this object
		 */
		public function toJsonString():String {
			// Convert to plain object using prepareForJson
			var plainObject:Object = prepareForJson();
			
			// Encode as JSON using native JSON encoder
			return NGJSON.stringify(plainObject);
		}
		
		/**
		 * Prepares this object for JSON serialization
		 * Container objects call this when rendering their nested objects to JSON.
		 * Ensures all nested objects are converted to plain objects and nulls are excluded.
		 * 
		 * @return Plain object ready for JSON encoding
		 */
		public function prepareForJson():Object {
			// Convert to plain object with recursive flattening and null exclusion
			return toObject(true, true);
		}
		
		/**
		 * Convert this object to a human-readable string representation
		 * Subclasses can override for more meaningful output.
		 * 
		 * @return String representation of this object
		 */
		public function toString():String {
			return this.objectName;
		}
	}
}

