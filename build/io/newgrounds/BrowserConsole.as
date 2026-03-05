package io.newgrounds {

	import flash.external.ExternalInterface;

	public class BrowserConsole {

		/**
		 * Logs a message to the browser console (if available) and optionally to the Flash debug console.
		 * @param message The message to log.
		 * @param traceMessage Whether to also output the message to the Flash debug console using trace
		 */
		public static function log(message:String, traceMessage:Boolean = true):void {
			if (ExternalInterface.available) {
				ExternalInterface.call("console.log", message);
			}
			if (traceMessage) {
				trace(message);
			}
		}
	}
}
