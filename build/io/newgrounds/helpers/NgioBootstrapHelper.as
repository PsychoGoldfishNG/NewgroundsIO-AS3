package io.newgrounds.helpers {

	import io.newgrounds.Core;
    import io.newgrounds.models.objects.ObjectFactory;
    import flash.events.TimerEvent;
    import flash.net.LocalConnection;
    import flash.utils.Timer;

    /**
     * Helper class for bootstrapping core, appState, timers and startup sequence to NGIO class.
     */
    public class NgioBootstrapHelper {

        /**
         * Initializes the core and performs the necessary bootstrap sequence.
         * 
         * @param appId Your app's unique identifier from Newgrounds
         * @param encryptionKey The encryption key from Newgrounds
         * @param buildVersion Your app's version number in XX.XX.XXXX format (optional)
         * @param useDebugMode If true, API calls won't actually save to the server (optional)
         * @return The initialized Core instance
         */
		public static function doInitializationSequence(appId:String, encryptionKey:String, buildVersion:String = null, useDebugMode:Boolean = false):Core {
			var core:Core = new Core(appId, encryptionKey, buildVersion, useDebugMode);
            logInitialView(core);

            return core;
        }

        /**
         * Logs the initial view of the app for analytics purposes
         * This should be called once when the app starts up
         */
        public static function logInitialView(core:Core):void {
            // Log initial view for analytics
            // Create a logView component - this tells the server we viewed this app
			var logViewComponent:* = ObjectFactory.CreateComponent("App", "logView", null, core);
			if (logViewComponent == null) {
				throw new Error("Could not create App.logView component");
			}
            // Set the host property if available from appState
            logViewComponent.host = (core.appState.host !== null) ? core.appState.host : "N/A";
			core.executeComponent(logViewComponent as io.newgrounds.BaseComponent, null);
        }

        /**
        * Sets up an automatic timer that pings the server periodically
        * This keeps active user sessions from expiring
        */
        public static function startKeepAlive(keepAliveTimeSeconds:Number, onKeepAliveTick:Function):Timer {
            // Create a timer that fires every KEEP_ALIVE_TIME seconds
            var keepAliveTimer:Timer = new Timer(keepAliveTimeSeconds * 1000);
            keepAliveTimer.addEventListener(TimerEvent.TIMER, function(event:TimerEvent):void {
                if (onKeepAliveTick != null) {
                    onKeepAliveTick.call(null);
                }
            });
            keepAliveTimer.start();
            return keepAliveTimer;
        }    

    }    
}