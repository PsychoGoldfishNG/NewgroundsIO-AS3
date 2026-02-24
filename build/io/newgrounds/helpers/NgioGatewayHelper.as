package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.models.objects.ObjectFactory;
	
	/**
	 * NgioGatewayHelper
	 *
	 * Hosts shared Gateway utility calls for NGIO wrapper methods.
	 */
	public class NgioGatewayHelper {
		private static const RETURN_DATETIME:String = "datetime";
		private static const RETURN_TIMESTAMP:String = "timestamp";
		private static const RETURN_DATE:String = "date";
		
		/**
		 * Loads server datetime string from Gateway.getDateTime.
		 */
		public static function loadGatewayDateTime(core:Core, callback:Function, thisArg:* = null):void {
			executeGatewayDateTime(core, callback, thisArg, RETURN_DATETIME);
		}
		
		/**
		 * Loads server timestamp value from Gateway.getDateTime.
		 */
		public static function loadGatewayTimestamp(core:Core, callback:Function, thisArg:* = null):void {
			executeGatewayDateTime(core, callback, thisArg, RETURN_TIMESTAMP);
		}
		
		/**
		 * Loads server time as native Date object.
		 */
		public static function loadGatewayDate(core:Core, callback:Function, thisArg:* = null):void {
			executeGatewayDateTime(core, callback, thisArg, RETURN_DATE);
		}
		
		/**
		 * Sends Gateway.ping and returns callback payload (pong/error).
		 */
		public static function sendPing(core:Core, callback:Function = null, thisArg:* = null):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			var component:* = ObjectFactory.CreateComponent("Gateway", "ping", null, core);
			if (component == null) {
				throw new Error("Could not create Gateway.ping component");
			}
			
			core.executeComponent(component as io.newgrounds.BaseComponent, function(result:*):void {
				if (callback == null) {
					return;
				}
				
				if (result == null) {
					callback.call(thisArg, null, null);
					return;
				}
				
				var error:* = (result.error !== null) ? result.error : null;
				callback.call(thisArg, 'pong', error);
			});
		}
		
		private static function executeGatewayDateTime(core:Core, callback:Function, thisArg:*, returnType:String):void {
			if (core == null) {
				throw new Error("Core not initialized");
			}
			
			var component:* = ObjectFactory.CreateComponent("Gateway", "getDateTime", null, core);
			if (component == null) {
				throw new Error("Could not create Gateway.getDateTime component");
			}
			
			core.executeComponent(component as io.newgrounds.BaseComponent, function(result:*):void {
				if (result == null) {
					if (callback !== null) {
						callback.call(thisArg, null, null);
					}
					return;
				}
				
				var error:* = (result.error !== null) ? result.error : null;
				if (callback !== null) {
					if (returnType == RETURN_DATETIME) {
						callback.call(thisArg, result.datetime, error);
					} else if (returnType == RETURN_DATE) {
						callback.call(thisArg, new Date(result.timestamp * 1000), error);
					} else {
						callback.call(thisArg, result.timestamp, error);
					}
				}
			});
		}
	}
}
