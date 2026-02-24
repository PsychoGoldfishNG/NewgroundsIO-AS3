package io.newgrounds.helpers {
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.navigateToURL;
	import flash.system.Security;
	import io.newgrounds.BaseComponent;
	import io.newgrounds.Core;
	
	/**
	 * CoreTransportHelper
	 *
	 * Encapsulates transport-specific delivery for Core requests.
	 *
	 * - Browser transport: redirects/navigates with form-post payload
	 * - HTTP transport: URLLoader lifecycle and callback forwarding
	 */
	public class CoreTransportHelper {
		
		/**
		 * Sends a request through browser navigation (redirect loaders).
		 */
		public static function sendBrowserRequest(core:Core, requestString:String, toExecute:*, callback:Function = null, thisArg:* = null):void {
			var browserRequest:URLRequest = new URLRequest(Core.GATEWAY_URL);
			browserRequest.method = URLRequestMethod.POST;
			browserRequest.contentType = "application/x-www-form-urlencoded";
			browserRequest.data = "request=" + encodeURIComponent(requestString);
			
			try {
				var browserTarget:String = resolveBrowserTarget(toExecute);
				
				if (core.debugNetworkCalls) {
					trace("NETWORK: Opening browser window to " + Core.GATEWAY_URL + " with target " + browserTarget);
					trace("         Request Data: " + requestString);
				}
				
				navigateToURL(browserRequest, browserTarget);
			} catch (e:Error) {
				if (core.debugNetworkCalls) {
					trace("NETWORK: Error opening browser window - " + e.message);
				}
			}
			
			if (callback != null) {
				callback.call(thisArg, null);
			}
		}
		
		/**
		 * Sends a request through URLLoader and forwards completion/error events to Core.
		 */
		public static function sendHttpRequest(core:Core, requestString:String, callback:Function = null, thisArg:* = null):void {
			Security.allowDomain("www.newgrounds.io", ".newgrounds.io", "*");
			
			var request:URLRequest = new URLRequest(Core.GATEWAY_URL);
			request.method = URLRequestMethod.POST;
			request.contentType = "application/x-www-form-urlencoded";
			request.data = "request=" + encodeURIComponent(requestString);
			
			var loader:URLLoader = new URLLoader();
			
			loader.addEventListener(Event.COMPLETE, function(event:Event):void {
				if (core.debugNetworkCalls) {
					trace("NETWORK: Received response from server");
					trace("         Response Data: " + loader.data);
				}
				core.forwardHTTPResponse(200, loader.data as String, callback, thisArg);
			});
			
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
				if (core.debugNetworkCalls) {
					trace("NETWORK: IOError occurred - " + event.text);
				}
				core.forwardHTTPResponse(500, null, callback, thisArg);
			});
			
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(event:SecurityErrorEvent):void {
				if (core.debugNetworkCalls) {
					trace("NETWORK: SecurityError occurred - " + event.text);
				}
				core.forwardHTTPResponse(403, null, callback, thisArg);
			});
			
			try {
				if (core.debugNetworkCalls) {
					trace("NETWORK: Sending request to " + Core.GATEWAY_URL);
					trace("         Request Data: " + requestString);
				}
				loader.load(request);
			} catch (e:Error) {
				if (core.debugNetworkCalls) {
					trace("NETWORK: Error sending request - " + e.message);
				}
				core.forwardHTTPResponse(500, null, callback, thisArg);
			}
		}
		
		/**
		 * Resolves browser target for redirect-capable components.
		 */
		private static function resolveBrowserTarget(toExecute:*):String {
			var browserTarget:String = "_blank";
			
			if (toExecute != null && !(toExecute is Array)) {
				var component:BaseComponent = null;
				
				if (toExecute.hasOwnProperty("componentModel")) {
					component = toExecute.componentModel as BaseComponent;
				} else if (toExecute.hasOwnProperty("component")) {
					component = toExecute.component as BaseComponent;
				}
				
				if (component != null && component.hasOwnProperty("browserTarget") && component.browserTarget != null) {
					browserTarget = component.browserTarget;
				}
			}
			
			return browserTarget;
		}
	}
}
