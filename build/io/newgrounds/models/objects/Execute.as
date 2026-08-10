

/**
 * Execute
 * 
 * Contains all the information needed to execute an API component.
 */
package io.newgrounds.models.objects {
	
	import io.newgrounds.BaseObject;
	import io.newgrounds.BaseComponent;
	
	public class Execute extends BaseObject {
		
		//==================== PROPERTIES ====================
		
		/**
		 * The name of the component you want to call, ie 'App.connect'.
		 */
		public var component:String = null;
		
		/**
		 * An object of parameters you want to pass to the component.
		 */
		public var parameters:* = null;
		
		/**
		 * A an encrypted #Execute object or array of #Execute objects.
		 */
		public var secure:String = null;
		
		/**
		 * An optional value that will be returned, verbatim, in the #Result object.
		 */
		public var echo:* = null;
		
		/**
		 * Reference to the component model being executed
		 * Used during serialization to determine if encryption is needed
		 */
		public var componentModel:BaseComponent;


		
		//==================== CONSTRUCTOR ====================
		
		public function Execute() {
			super();
		}
		
		//==================== ABSTRACT PROPERTY OVERRIDES ====================
		
		/**
		 * Object name for debugging and type checking
		 */
		override public function get objectName():String {
			return "Execute";
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
			return ["component","parameters","secure","echo"];
		}
		
		/**
		 * Required properties for validation
		 */
		override public function get requiredProperties():Array {
			// 'component' and 'secure' are mutually exclusive. A plain Execute carries
			// 'component' + 'parameters'; an encrypted one carries only 'secure'. The schema
			// expresses this with not_required_if, which the generator doesn't model yet, so
			// listing both here would make hasValidProperties() impossible to satisfy.
			// Neither is listed, and the hasValidProperties() override in methods.ejs
			// enforces the real rule instead.
			return [];
		}
		
		/**
		 * Type casting map for deserializing properties
		 */
		override public function get castTypes():Object {
			return {
				"parameters": "Array"
			};
		}
		
		//==================== CUSTOM METHODS ====================
		/**
		 * Sets the component to be executed
		 * 
		 * @param componentModel A component model instance with all required properties set
		 */
		public function setComponent(componentModel:BaseComponent):void {
			// Store reference to the component
			this.componentModel = componentModel;
			this.component = componentModel.objectName;
			if (componentModel.hasOwnProperty("prepareForJson")) {
				this.parameters = componentModel.prepareForJson();
			} else if (componentModel.hasOwnProperty("toObject")) {
				this.parameters = componentModel.toObject();
			} else {
				this.parameters = null;
			}
			// Note: Encryption for secure components is handled by HttpRequestHelper
			// This Execute object just stores the component name and parameters
		}

		/**
		 * Validates that exactly one of component / secure is set.
		 *
		 * Pairs with required_properties.ejs, which returns an empty list. The schema marks
		 * both properties required, but they are mutually exclusive - a plain "all present"
		 * check can never pass. This enforces the actual rule instead.
		 */
		override public function hasValidProperties():Boolean {
			if (!super.hasValidProperties()) {
				return false;
			}

			var hasComponent:Boolean = (this.component != null && this.component.length > 0);
			var hasSecure:Boolean = (this.secure != null && this.secure.length > 0);

			return (hasComponent || hasSecure) && !(hasComponent && hasSecure);
		}
	}
}
