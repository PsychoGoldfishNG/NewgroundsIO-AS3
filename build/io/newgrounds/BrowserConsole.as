package io.newgrounds {

	import flash.external.ExternalInterface;

	public class BrowserConsole {

		public static function log(message:String):void {
			if (ExternalInterface.available) {
				ExternalInterface.call("console.log", message);
			} else {
				trace(message);
			}
		}
	}
}
