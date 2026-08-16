package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.Errors;
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
			
			core.executeComponent(component as io.newgrounds.BaseComponent, function(response:io.newgrounds.models.objects.Response):void {
				if (callback == null) {
					return;
				}
				
				// All three failure layers, the same pattern Medal.unlock and
				// AppState.loadData use.
				//
				// A null response - no HTTP reply at all - left `error` null and
				// so reported the event as logged. A component reporting
				// success:false with no error object did the same. Both are
				// silent failures: the caller is told the event reached the
				// gateway when nothing did.
				var error:* = null;

				if (response === null || response.success !== true) {
					error = (response !== null && response.error !== null)
						? response.error
						: Errors.getError();
				} else {
					var result:* = response.getResult();

					if (result === null) {
						error = Errors.getError(Errors.INVALID_RESPONSE);
					} else if (result.success !== true) {
						error = (result.error !== null) ? result.error : Errors.getError();
					}
				}

				callback.call(thisArg, error);
			});
		}
	}
}
