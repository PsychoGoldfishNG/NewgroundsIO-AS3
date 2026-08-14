package io.newgrounds.helpers {

	import io.newgrounds.Errors;
	import io.newgrounds.models.objects.NgioError;

	/**
	 * HttpStatusHelper
	 *
	 * Turns an HTTP status code into a specific NgioError, so a failed load says
	 * "the server is down" or "that file is gone" rather than "Stream Error
	 * #2032".
	 *
	 * The Errors constants were already chosen to mirror HTTP - 400, 403, 404,
	 * 429, 500, 503, 504 - so most codes map straight across.
	 *
	 * WHAT FLASH PLAYER ACTUALLY GIVES US, because this is easy to over-trust:
	 *
	 *  - HTTPStatusEvent.HTTP_STATUS carries `status`, and is the only status
	 *    information available in the browser plugin. It is frequently 0, because
	 *    Flash Player can only report a code where the host browser exposes one.
	 *    Treat 0 as "unknown", never as an error in itself.
	 *
	 *  - responseHeaders and responseURL live on HTTPStatusEvent.HTTP_RESPONSE_STATUS,
	 *    which is AIR ONLY. There is no way to read response headers from the
	 *    browser plugin, so anything richer than the status code is out of reach.
	 *
	 *  - A non-2xx response makes Flash Player fire IOErrorEvent and discard the
	 *    body. So a 500 never reaches a JSON parser; it arrives as an IO error
	 *    with no detail. That is exactly the case this helper improves.
	 *
	 *  - The inverse case gets no help from the status at all: a 200 carrying an
	 *    HTML error page, a proxy interstitial or a captive-portal login is a
	 *    perfectly good HTTP response. Only inspecting the BODY catches those,
	 *    which is why NGJSON.parse must stay strict.
	 */
	public class HttpStatusHelper {

		/** No status was reported - the common case in the browser plugin */
		public static const UNKNOWN_STATUS:int = 0;

		/**
		 * Builds the most specific error the status supports.
		 *
		 * @param status HTTP status code, or 0 when none was reported
		 * @param context What was being loaded, for the message
		 * @param detail Optional extra text, such as an IOErrorEvent's text
		 */
		public static function errorForStatus(status:int, context:String, detail:String = null):NgioError {
			var code:int = codeForStatus(status);
			var message:String = describe(status, context);

			if (detail != null && detail.length > 0) {
				message += " (" + detail + ")";
			}

			return Errors.getError(code, message, false) as NgioError;
		}

		/**
		 * Maps an HTTP status onto the closest Errors constant.
		 *
		 * Unrecognised codes fall back by CLASS rather than to a generic error,
		 * so a 502 still reads as a server problem and a 418 still reads as a
		 * bad request.
		 */
		public static function codeForStatus(status:int):int {
			switch (status) {
				case 400: return Errors.BAD_REQUEST;
				case 403: return Errors.USER_FORBIDDEN;
				case 404: return Errors.NOT_FOUND;
				case 429: return Errors.TOO_MANY_REQUESTS;
				case 500: return Errors.SERVER_ERROR;
				case 503: return Errors.SERVER_UNAVAILABLE;
				case 504: return Errors.GATEWAY_TIMEOUT;
			}

			if (status >= 500 && status <= 599) {
				return Errors.SERVER_ERROR;
			}

			if (status >= 400 && status <= 499) {
				return Errors.BAD_REQUEST;
			}

			// Includes 0 (no status reported) and any 2xx that got here, which
			// means the request succeeded and the BODY was the problem.
			return Errors.INVALID_RESPONSE;
		}

		/**
		 * A sentence naming what failed and what the server said, if anything.
		 */
		public static function describe(status:int, context:String):String {
			if (status == UNKNOWN_STATUS) {
				// Not a fault - the browser simply did not hand Flash a code.
				return context + " failed, and no HTTP status was reported";
			}

			if (status >= 200 && status <= 299) {
				return context + " returned HTTP " + status + " but the body was not valid JSON";
			}

			return context + " failed with HTTP " + status;
		}
	}
}
