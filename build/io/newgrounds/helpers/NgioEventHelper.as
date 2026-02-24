package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.models.objects.ObjectFactory;
	
	/**
	 * NgioEventHelper
	 *
	 * Executes Event.* component calls on behalf of NGIO wrapper methods.
	 */
	public class NgioEventHelper {
		
		/**
		 * Sends Event.logEvent with host and event name fields.
		 */
		public static function logEvent(core:Core, eventName:String, callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			var component:* = ObjectFactory.CreateComponent("Event", "logEvent", null, core);
			if (component == null) {
				throw new Error("Could not create Event.logEvent component");
			}
			
			component.host = (core.appState.host !== null) ? core.appState.host : "N/A";
			component.event_name = eventName;
			
			core.executeComponent(component as io.newgrounds.BaseComponent, function(result:*):void {
				if (callback == null) {
					return;
				}
				
				var error:* = null;
				if (result !== null && result.error !== null) {
					error = result.error;
				}
				callback.call(thisArg, error);
			});
		}
	}
}
