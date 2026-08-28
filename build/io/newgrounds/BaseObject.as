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
		
		/**
		 * The model this one is nested inside, if any.
		 *
		 * Assigned by importFromObject() when this object is built as another
		 * model's property. Used only by getObjectPath(), which is a debugging
		 * aid - nothing in the request or response path reads it.
		 */
		public var parent:BaseObject;

		/**
		 * The property name this model occupies on its parent, with an index
		 * for array members ("scores[3]").
		 *
		 * Both this and parent must be set for getObjectPath() to walk upward.
		 */
		public var parentPropertyName:String;
	
        /** Error details if something went wrong (can be set on any object) */
        public var error:io.newgrounds.models.objects.NgioError = null;

        /**
         * The App ID this object's data was loaded from, when it came from a
         * DIFFERENT app than the one this client is running as. Null for
         * ordinary local data, which is the overwhelmingly common case.
         *
         * Set by NGIO's loadExternal* methods, on the returned model and
         * everything nested inside it.
         *
         * It exists because a model returned by a cross-app read is otherwise
         * indistinguishable from a local one, while behaving very differently.
         * Cross-app access is READ-ONLY: no component that writes accepts an
         * app_id, so calling one on a foreign object sends that object's id
         * against YOUR app. Every write method checks this via
         * assertNotForeign() - see the note there for why that check is not
         * merely cosmetic.
         */
        public var foreignAppId:String = null;

        /** Static counter for tracking object IDs (for debugging) */
        private static var objectIDTracking:Number = 0;

        /** Unique object ID assigned during construction (for debugging) */
        public var objectId:Number = -1;

        /**
         * True if this object's data was loaded from another app.
         *
         * Prefer this to testing foreignAppId directly - it treats an empty
         * string the same as null, so a stamp that never took cannot read as a
         * foreign object.
         */
        public function isForeign():Boolean {
            return this.foreignAppId != null && this.foreignAppId.length > 0;
        }

        /**
         * Refuses a write on an object that was loaded from another app.
         *
         * Called at the top of every method that writes - before any work is
         * done and before anything is sent - so a mistake surfaces at the call
         * site rather than as a puzzling gateway error later.
         *
         * WHY THIS THROWS RATHER THAN REPORTING VIA CALLBACK: calling a write
         * on a foreign object is a programming error, not a runtime condition
         * the caller can recover from. Every write method takes an OPTIONAL
         * callback, so an error delivered that way would be silently discarded
         * by the callers most likely to make the mistake.
         *
         * WHY IT MATTERS MOST FOR CloudSave: medal and scoreboard ids are
         * globally unique, so a misdirected write is rejected by the gateway -
         * confusing, but harmless. SaveSlot.id is a per-app SLOT NUMBER, and
         * every app has a slot 1. Writing through a foreign slot therefore
         * succeeds, silently overwriting the caller's OWN save data. This
         * check is the only thing standing between a cross-app read and real
         * data loss.
         *
         * @param action Name of the refused method, e.g. "unlock()"
         * @param consequence One sentence on what would have happened
         */
        protected function assertNotForeign(action:String, consequence:String):void {
            if (!this.isForeign()) {
                return;
            }

            throw new ArgumentError(
                this.toString() + " was loaded from app " + this.foreignAppId + ", not this one, " +
                "and " + action + " writes through this app's session. " + consequence + " " +
                "Cross-app access is read-only - see the NGIO.loadExternal* methods."
            );
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

			// make an empty version of this object to reference default values for properties that aren't provided in the import
			var defaultObject:BaseObject = buildDefaultInstance();

			for (var i:int = 0; i < propNames.length; i++) {
				var propertyName:String = propNames[i] as String;
				
				// Check if property exists in the import object
				if (!(propertyName in importObject)) {
					if (objectType == "component") {
						// A component is built from a developer-supplied PARTIAL parameter
						// set (see ObjectFactory.CreateComponent), not a complete snapshot.
						// Absent means "not sent" - null it explicitly so it drops out of
						// toObject()'s excludeNulls pass instead of reappearing on the wire
						// as its type's zero value.
						//
						// NOTE for String/Object-typed properties this works as intended.
						// For a strictly-typed Boolean/int/uint/Number property, ActionScript
						// 3 coerces an assigned null back to that type's own default
						// (false/0/NaN) rather than storing null - so this is a no-op for
						// those two properties in the current schema (ScoreBoard.getScores.social,
						// App.startSession.force), which still serialize with their zero value.
						// Achieving a genuine drop for those would need a nullable/boxed
						// property type, which is a larger change than this fix. AS2 and
						// TypeScript (loosely-typed at this boundary) do not have this
						// limitation - see their BaseObject implementations.
						this[propertyName] = null;
					} else if (defaultObject != null) {
						this[propertyName] = defaultObject[propertyName];
					}
					// else: keep whatever the class-level initializer set
					continue;
				}
				
				var propertyValue:* = importObject[propertyName];

				// === STANDARD CAST AND ASSIGN ===
				var castValue:* = castToExpectedType(propertyName, propertyValue);
				this[propertyName] = castValue;

				// Record where the nested model landed, so getObjectPath() can
				// name it. Done here rather than inside castToExpectedType so a
				// subclass overriding the cast still gets the links, and so
				// arrays are handled in one place.
				stampChildPosition(castValue, propertyName);
			}

            // ==================== CHECK FOR ERROR PROPERTY ====================
            // If the import object contains an error property, create an NgioError model
            if ("error" in importObject && importObject.error != null) {
                // Create a new NgioError object using the factory
                this.error = ObjectFactory.CreateObject("Error", importObject.error, this.core) as io.newgrounds.models.objects.NgioError;

                // `error` is not in propertyNames, so the loop above never saw
                // it - stamp it here or a failed nested model reports no path.
                stampChildPosition(this.error, "error");
            }
		}

		/**
		 * A throwaway instance used to read this model's declared defaults.
		 *
		 * A result's objectName is a dotted component path ("Medal.unlock") that
		 * ObjectFactory.CreateObject() cannot resolve by objectName alone - see
		 * BaseObject.md, "The default instance and dotted names". Dispatching to
		 * CreateResult for objectType == "result" lets it split the scope and method
		 * apart, so declared defaults apply there too.
		 *
		 * Deliberately NOT extended to objectType == "component": a component is
		 * built from a developer-supplied PARTIAL parameter set (see
		 * ObjectFactory.CreateComponent), not a complete server snapshot, so the
		 * "absent means reset to the declared default" reasoning does not apply -
		 * an omitted optional parameter needs to stay absent so it drops off the
		 * wire in toObject(), not reappear as its type's default value. Return null
		 * for components and let the caller's "keep the constructor value" fallback
		 * handle it, same as it always effectively has.
		 *
		 * @return A fresh instance of this same type, or null if it couldn't be built
		 */
		private function buildDefaultInstance():BaseObject {
			var instance:BaseObject = null;
			try {
				if (objectType == "object") {
					instance = ObjectFactory.CreateObject(objectName, null, core);
				} else if (objectType == "result") {
					var dotIndex:int = objectName.indexOf(".");
					if (dotIndex != -1) {
						var scope:String = objectName.substring(0, dotIndex);
						var method:String = objectName.substring(dotIndex + 1);
						instance = ObjectFactory.CreateResult(scope, method, null, core);
					}
				}
			} catch (e:Error) {
				instance = null;
			}
			return instance;
		}

		/**
		 * Convert a property value to its correct type
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
		 * Returns the fully-qualified TYPE name of this object.
		 *
		 * This is an identity, not a location: the same class reports the same
		 * name wherever it sits. That is what makes it usable as the type check
		 * in importFromObject() - a Session is a Session whether it arrived
		 * standalone or nested inside a checkSession result.
		 *
		 * For where an object sits in a tree, use getObjectPath().
		 *
		 * NOTE: this method used to fold parent/parentPropertyName in, which
		 * would have made it positional. Nothing ever assigned those, so the
		 * branch never ran - and the moment they WERE assigned it broke
		 * importFromObject, because AppStateResultUpdateHelper imports a nested
		 * result.session into the standalone appState.session. Two models of the
		 * same class must compare equal regardless of where each one came from.
		 *
		 * @return Qualified name like "object.User" or "component.Medal.unlock"
		 */
		public function getFullObjectName():String {
			return objectType + "." + objectName;
		}

		/**
		 * Returns where this object sits in the model tree, for debugging.
		 *
		 * A standalone model reports its type name. A nested one reports its
		 * parent's path plus the property it occupies, so a Medal reached
		 * through an unlock result reads:
		 *
		 *     result.Medal.unlock.medal
		 *
		 * and a Score inside a getScores result reads:
		 *
		 *     result.ScoreBoard.getScores.scores[3]
		 *
		 * That is the difference between "a Score failed to import" and knowing
		 * WHICH score, which is the whole reason the parent links exist.
		 *
		 * Never use this for type comparison - use getFullObjectName().
		 *
		 * @return The path from the root model down to this one
		 */
		public function getObjectPath():String {
			// Walk upward rather than recursing, so a cycle cannot blow the
			// stack. Nothing should ever build one, but a debugging aid that
			// crashes the app while you are debugging is worse than useless.
			var segments:Array = [];
			var node:BaseObject = this;
			var guard:int = 0;

			while (node != null && guard < 64) {
				if (node.parent != null && node.parentPropertyName != null) {
					segments.unshift(node.parentPropertyName);
					node = node.parent;
				} else {
					// Reached the root - its own type name starts the path.
					segments.unshift(node.getFullObjectName());
					node = null;
				}
				guard++;
			}

			return segments.join(".");
		}

		/**
		 * Records this object's position in the tree, so getObjectPath() can
		 * report it later.
		 *
		 * Called from importFromObject() for every nested model it builds.
		 * Arrays get an index, because "a Score failed" is not an answer when
		 * a scoreboard returned a hundred of them.
		 *
		 * @param value The freshly cast property value - model, array, or scalar
		 * @param propertyName The property it was assigned to
		 */
		protected function stampChildPosition(value:*, propertyName:String):void {
			if (value is BaseObject) {
				(value as BaseObject).parent = this;
				(value as BaseObject).parentPropertyName = propertyName;
				return;
			}

			if (value is Array) {
				var items:Array = value as Array;
				for (var i:int = 0; i < items.length; i++) {
					if (items[i] is BaseObject) {
						(items[i] as BaseObject).parent = this;
						(items[i] as BaseObject).parentPropertyName = propertyName + "[" + i + "]";
					}
				}
			}

			// Scalars have no position to record.
		}
		
		/**
		 * Check if this object has all required properties
		 * Objects from the server might be incomplete. We validate before using them.
		 * 
		 * @return true if all required properties are present, false if any are missing
		 */
		public function hasValidProperties():Boolean {
			return getPreflightError() == null;
		}

		/**
		 * The reason this object would be rejected, or null if it is valid.
		 *
		 * hasValidProperties() answers "is it valid?"; this answers "why not?",
		 * which is what a caller needs when the answer arrives instead of a
		 * server response. The two share one implementation so they can never
		 * disagree.
		 *
		 * The codes deliberately match what the gateway would have returned for
		 * the same request, so a locally-refused call is indistinguishable from
		 * a server-refused one apart from its speed. A game branching on
		 * error.code needs no new cases.
		 *
		 * @return An NgioError describing the first problem found, or null
		 */
		public function getPreflightError():io.newgrounds.models.objects.NgioError {
			var reqProps:Array = requiredProperties;

			// Check each required property
			for (var i:int = 0; i < reqProps.length; i++) {
				var requiredProperty:String = reqProps[i] as String;

				if (this[requiredProperty] == null || this[requiredProperty] == undefined) {
					// Missing a required property!
					return missingPropertyError(requiredProperty, "is missing");
				}

				// Check for empty strings
				if (this[requiredProperty] is String) {
					if ((this[requiredProperty] as String).length == 0) {
						return missingPropertyError(requiredProperty, "is an empty string");
					}
				}

				// Check for empty arrays
				if (this[requiredProperty] is Array) {
					if ((this[requiredProperty] as Array).length == 0) {
						return missingPropertyError(requiredProperty, "is an empty array");
					}
				}

				// Note: The number 0 and boolean false are considered valid values
			}

			// All required properties are present and valid
			return null;
		}

		/**
		 * Builds the error for a required property that is absent or empty.
		 *
		 * MISSING_PARAMETER (102) is what the gateway returns for the same
		 * condition. The message names the object and the property, because
		 * "missing a required parameter" on its own sends a developer reading
		 * their own code rather than the one line that is wrong.
		 */
		protected function missingPropertyError(propertyName:String, problem:String):io.newgrounds.models.objects.NgioError {
			return io.newgrounds.Errors.getError(
				io.newgrounds.Errors.MISSING_PARAMETER,
				getFullObjectName() + " requires '" + propertyName + "', which " + problem + ".",
				false
			) as io.newgrounds.models.objects.NgioError;
		}
		
		/**
		 * Get a list of all validation errors
		 * Provides detailed error information instead of just true/false
		 *
		 * Returns plain strings, not NgioError models, on purpose: every entry is the
		 * same MISSING_PARAMETER condition, so a typed model per entry adds nothing to
		 * branch on. This is a developer-facing report; callers needing one branchable
		 * typed error use getPreflightError().
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

