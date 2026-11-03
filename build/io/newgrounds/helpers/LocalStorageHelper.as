package io.newgrounds.helpers {

	import flash.net.SharedObject;
	import flash.net.SharedObjectFlushStatus;

	/**
	 * LocalStorageHelper
	 *
	 * Keyed string storage for local data that outlives the SWF: save slot
	 * copies, and medal unlocks still waiting on the gateway. Backed by the same
	 * "ngio" SharedObject the saved session id uses.
	 *
	 * A write reports failure rather than throwing. Flash can refuse one: the
	 * player may have local storage turned off, or the data may pass the space
	 * the player allows. Callers treat a failed write as a failed local copy,
	 * not an error.
	 */
	public class LocalStorageHelper {

		private static const SHARED_OBJECT_NAME:String = "ngio";

		/**
		 * Replaces the SharedObject with a store of your own: an object with
		 * getValue(key):String, setValue(key, value):Boolean and
		 * removeValue(key):Boolean. Null, the default, uses the SharedObject.
		 * Used by the offline tests, and by a game that keeps its data elsewhere.
		 */
		public static var store:Object = null;

		/** The stored value, or null if there is none or it can't be read. */
		public static function getValue(key:String):String {
			if (store != null) return store.getValue(key);
			try {
				var so:SharedObject = SharedObject.getLocal(SHARED_OBJECT_NAME);
				if (so.data.hasOwnProperty(key)) return so.data[key] as String;
			} catch (e:Error) {
			}
			return null;
		}

		/** Stores a value, returning whether it was written. */
		public static function setValue(key:String, value:String):Boolean {
			if (store != null) return store.setValue(key, value);
			try {
				var so:SharedObject = SharedObject.getLocal(SHARED_OBJECT_NAME);
				so.data[key] = value;
				// PENDING means Flash is asking the player for more space. The value
				// may still be written if they agree, but nothing is stored yet, so it
				// doesn't count as a write.
				return so.flush() == SharedObjectFlushStatus.FLUSHED;
			} catch (e:Error) {
			}
			return false;
		}

		/** Removes a value, returning whether that was written. */
		public static function removeValue(key:String):Boolean {
			if (store != null) return store.removeValue(key);
			try {
				var so:SharedObject = SharedObject.getLocal(SHARED_OBJECT_NAME);
				delete so.data[key];
				return so.flush() == SharedObjectFlushStatus.FLUSHED;
			} catch (e:Error) {
			}
			return false;
		}
	}
}
