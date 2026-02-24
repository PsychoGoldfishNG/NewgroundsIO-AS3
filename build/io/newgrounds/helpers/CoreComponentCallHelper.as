package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.models.objects.ObjectFactory;
	
	/**
	 * CoreComponentCallHelper
	 *
	 * Handles convenience call flow for Core.callComponent:
	 * path parsing, component creation, parameter import, callback adaptation,
	 * and normalized error callback behavior.
	 */
	public class CoreComponentCallHelper {
		
		public static function callComponent(core:Core, componentPath:String, componentParams:Object = null, callback:Function = null, thisArg:* = null, callbackParams:Object = null):void {
			var parts:Array = componentPath.split(".");
			if (parts.length != 2) {
				trace("callComponent Error: Invalid component path - " + componentPath);
				callError(callback, thisArg, callbackParams, "Invalid component path: " + componentPath);
				return;
			}
			
			var componentName:String = parts[0];
			var methodName:String = parts[1];
			
			try {
				var component:* = ObjectFactory.CreateComponent(componentName, methodName, null, core);
				if (component == null) {
					throw new Error("Component not found: " + componentPath);
				}
				
				if (componentParams != null) {
					if (component.hasOwnProperty("importFromObject")) {
						component.importFromObject(componentParams);
					} else {
						for (var key:String in componentParams) {
							if (component.hasOwnProperty(key)) {
								component[key] = componentParams[key];
							}
						}
					}
				}
				
				var wrappedCallback:Function = null;
				if (callback != null) {
					wrappedCallback = function(result:*):void {
						callback.call(thisArg, result, callbackParams);
					};
				}
				
				core.executeComponent(component as io.newgrounds.BaseComponent, wrappedCallback);
			} catch (e:*) {
				trace("callComponent Error: " + e);
				callError(callback, thisArg, callbackParams, "Component not found: " + componentPath);
			}
		}
		
		private static function callError(callback:Function, thisArg:*, callbackParams:Object, message:String):void {
			if (callback != null) {
				var errorResult:Object = { success: false, error: message };
				callback.call(thisArg, errorResult, callbackParams);
			}
		}
	}
}
