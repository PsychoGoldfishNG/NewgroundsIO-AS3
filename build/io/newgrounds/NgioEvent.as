package io.newgrounds {
	import flash.events.Event;
    import io.newgrounds.models.objects.SaveSlot;
	
    /**
     * Custom event class for Newgrounds IO events.
     */
	public class NgioEvent extends Event {

        //==================== EVENT TYPES ====================\\

        /**
         * Dispatched when a connector has completed preloading data, and finalizing user session.
         */
		public static const CONNECTOR_COMPLETED:String = "connectorCompleted";
		
        /**
         * Dispatched when a component clip has been closed (via the [X] button).
         */
		public static const COMPONENT_CLOSED:String = "componentClosed";

        /**
         * Dispatched when a SaveSlot data has been loaded from the server.
         */
		public static const SAVESLOT_LOADED:String = "saveSlotLoaded";
		
        /**
         * Dispatched when a SaveSlot data has been saved to the server.
         */
		public static const SAVESLOT_SAVED:String = "saveSlotSaved";
		
        /**
         * Dispatched when a SaveSlot data has been cleared from the server.
         */
		public static const SAVESLOT_CLEARED:String = "saveSlotCleared";
		
        /**
         * The SaveSlot associated with this event (if applicable)
         */
        public var saveSlot:io.newgrounds.models.objects.SaveSlot;

        /**
         * An error associated with this event (if applicable)
         */
        public var error:io.newgrounds.models.objects.NgioError;

        /**
         * Contains data from a SaveSlot load operation.
         */
		public var data:*;

        /**
         * Creates a new NgioEvent instance.
         * @param type The event type
         * @param bubbles Whether the event bubbles
         * @param cancelable Whether the event is cancelable
         */
		public function NgioEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);
            
            // set these as needed after instance creation
            data = null;
            saveSlot = null;
            error = null;
		}
	}
}
