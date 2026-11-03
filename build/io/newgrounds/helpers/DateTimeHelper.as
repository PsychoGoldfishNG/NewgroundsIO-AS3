package io.newgrounds.helpers {

	/**
	 * DateTimeHelper
	 *
	 * ISO 8601 datetimes, for comparing a local save copy against the cloud's.
	 * Flash's Date.parse() doesn't read ISO 8601, and Date has no toISOString().
	 */
	public class DateTimeHelper {

		private static const ISO_PATTERN:RegExp = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/;

		/**
		 * Milliseconds since the epoch for an ISO 8601 datetime such as
		 * "2026-08-25T17:42:42-04:00" or "2026-08-25T21:42:42.000Z", or NaN if it
		 * won't parse. The offset is applied, so two datetimes from different time
		 * zones compare correctly. One with no offset is read as UTC.
		 */
		public static function parseIso(value:String):Number {
			if (value == null) return NaN;
			var match:Object = ISO_PATTERN.exec(value);
			if (match == null) return NaN;

			var milliseconds:Number = 0;
			if (match[7] != null && match[7] != "") {
				// ".5" is 500ms and ".123456" is 123ms, so scale the digits to three.
				milliseconds = Math.floor(Number("0" + match[7]) * 1000);
			}

			var time:Number = Date.UTC(int(match[1]), int(match[2]) - 1, int(match[3]),
				int(match[4]), int(match[5]), int(match[6]), milliseconds);

			var zone:String = match[8];
			if (zone != null && zone != "" && zone != "Z") {
				var sign:int = (zone.charAt(0) == "-") ? -1 : 1;
				var digits:String = zone.substr(1).replace(":", "");
				var offsetMinutes:int = int(digits.substr(0, 2)) * 60 + int(digits.substr(2, 2));
				time -= sign * offsetMinutes * 60000;
			}
			return time;
		}

		/** An ISO 8601 datetime in UTC, such as "2026-08-25T21:42:42.000Z". */
		public static function toIso(time:Number):String {
			var date:Date = new Date(time);
			return date.fullYearUTC + "-" + pad(date.monthUTC + 1, 2) + "-" + pad(date.dateUTC, 2)
				+ "T" + pad(date.hoursUTC, 2) + ":" + pad(date.minutesUTC, 2) + ":" + pad(date.secondsUTC, 2)
				+ "." + pad(date.millisecondsUTC, 3) + "Z";
		}

		/** The current time as an ISO 8601 datetime in UTC. */
		public static function nowIso():String {
			return toIso(new Date().time);
		}

		private static function pad(value:int, width:int):String {
			var text:String = String(value);
			while (text.length < width) text = "0" + text;
			return text;
		}
	}
}
