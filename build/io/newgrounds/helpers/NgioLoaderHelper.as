package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.Errors;
	import io.newgrounds.models.objects.ObjectFactory;
	
	/**
	 * NgioLoaderHelper
	 *
	 * Centralizes Loader.* URL component execution for open/load NGIO methods.
	 */
	public class NgioLoaderHelper {
		
		/**
		 * Executes a loader component configured for redirect/browser open behavior.
		 */
		public static function openUrl(core:Core, operation:String, target:String = "_blank", logStat:Boolean = true, referralName:String = null):void {
			var component:* = createLoaderComponent(core, operation, referralName);
			component.browserTarget = target;
			component.log_stat = logStat;
			component.redirect = true;
			core.executeComponent(component as io.newgrounds.BaseComponent, null);
		}
		
		/**
		 * Executes a loader component configured to return a URL via callback.
		 */
		public static function loadUrl(core:Core, operation:String, logStat:Boolean = true, callback:Function = null, thisArg:* = null, referralName:String = null):void {
			var component:* = createLoaderComponent(core, operation, referralName);
			component.log_stat = logStat;
			component.redirect = false;
			
			core.executeComponent(component as io.newgrounds.BaseComponent, function(response:io.newgrounds.models.objects.Response):void {

				if (callback !== null) {
					var url:String = null;
					var error:* = null;

					// A failed load surfaces at either of two levels, and both have
					// to be checked - the same pattern Medal.unlock and
					// ScoreBoard.getScores use.
					//
					// Only the component level was checked here. When the REQUEST
					// fails there is no result to read an error from, so the block
					// was skipped entirely and the caller got (null, null): no url
					// and no reason. Any transport failure - server down, no
					// network, a stream error - looked identical to success with an
					// empty url.
					if (response === null || response.success !== true) {
						error = (response !== null && response.error !== null)
							? response.error
							: Errors.getError();
					} else {
						var result:* = response.getResult();

						if (result === null) {
							error = Errors.getError(Errors.INVALID_RESPONSE);
						} else if (result.error !== null) {
							error = result.error;
						} else {
							url = result.url;
						}
					}

					callback.call(thisArg, url, error);
				}
			});
		}
		
		private static function createLoaderComponent(core:Core, operation:String, referralName:String = null):* {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			var component:* = ObjectFactory.CreateComponent("Loader", operation, null, core);
			if (component == null) {
				throw new Error("Could not create Loader." + operation + " component");
			}
			
			component.host = (core.appState.host !== null) ? core.appState.host : "N/A";
			if (referralName !== null) {
				component.referral_name = referralName;
			}
			
			return component;
		}
	}
}
