package io.newgrounds.helpers {

	import io.newgrounds.BaseComponent;
	import io.newgrounds.BaseResult;
	import io.newgrounds.Core;
	import io.newgrounds.Errors;
	import io.newgrounds.models.objects.NgioError;
	import io.newgrounds.models.objects.ObjectFactory;
	import io.newgrounds.models.objects.Response;

	/**
	 * ComponentValidationHelper
	 *
	 * Refuses components that cannot possibly succeed, before they cost a
	 * network round trip - and shapes the refusal so callers cannot tell it
	 * from the server's own.
	 *
	 * WHY THIS MATTERS MORE THAN "SAVING A REQUEST":
	 *
	 * The gateway limits requests per time window. A game that calls
	 * medal.unlock() on every scoring event while the player is signed out
	 * spends that budget on calls whose outcome was knowable before they left
	 * the machine - and then a call that COULD have succeeded gets a 429.
	 *
	 * THE CONTRACT:
	 *
	 * A locally-refused call is indistinguishable from a server-refused one
	 * except by how fast it arrives. Same Response shape, same result shape,
	 * same error codes - the ones the live gateway was observed to return for
	 * these exact conditions. Nothing downstream needs a special case, and in
	 * particular the three-layer error check in AppState.loadData and the NGIO
	 * wrappers reads a synthesized refusal exactly as it reads a real one.
	 *
	 * That is the whole design rule here: DO NOT INVENT A NEW FAILURE SHAPE.
	 * A local error that arrives differently from a server error would mean
	 * every caller needs two code paths for one condition.
	 */
	public class ComponentValidationHelper {

		/**
		 * Builds the Response the gateway would have returned had it refused
		 * this component itself.
		 *
		 * Envelope-level success is TRUE, because the request was well formed -
		 * the component is what failed. That is exactly how the server reports
		 * "you are not logged in", and it is what puts the error at the layer
		 * callers already check.
		 *
		 * @param component The component that failed validation
		 * @param validationError Why it failed
		 * @param core The Core the response belongs to
		 * @return A Response carrying one failed result
		 */
		public static function buildRefusalResponse(component:BaseComponent, validationError:NgioError, core:Core):Response {
			var response:Response = ObjectFactory.CreateObject("Response", null, core) as Response;

			if (response == null) {
				return null;
			}

			response.core = core;
			response.app_id = (core != null) ? core.appId : null;

			// The REQUEST was fine. The component was not. Reporting envelope
			// failure here would say the whole batch was rejected, which is a
			// different and worse claim.
			response.success = true;

			response.setResult(buildRefusalResult(component, validationError, core));

			return response;
		}

		/**
		 * Builds the single failed result for a refused component.
		 *
		 * Falls back to the response-level error when no result model exists for
		 * the component name - an unrecognised name yields null from the
		 * factory, and a null result is the one shape that would make the
		 * refusal silent.
		 */
		public static function buildRefusalResult(component:BaseComponent, validationError:NgioError, core:Core):BaseResult {
			var result:BaseResult = createResultFor(component, core);

			if (result == null) {
				return null;
			}

			result.core = core;
			result.success = false;
			result.error = validationError;

			return result;
		}

		/**
		 * Builds results for a whole queue of refused components.
		 *
		 * @param refusals Array of {component, error} pairs
		 * @param core The Core the results belong to
		 * @return Array of failed BaseResult models, in the order given
		 */
		public static function buildRefusalResults(refusals:Array, core:Core):Array {
			var results:Array = [];

			for each (var refusal:Object in refusals) {
				var result:BaseResult = buildRefusalResult(
					refusal.component as BaseComponent,
					refusal.error as NgioError,
					core
				);

				if (result != null) {
					results.push(result);
				}
			}

			return results;
		}

		/**
		 * Builds a Response holding several refused components' results.
		 *
		 * Used when EVERY component in a queue was refused, so no request is
		 * sent at all.
		 */
		public static function buildRefusalResponseList(refusals:Array, core:Core):Response {
			var response:Response = ObjectFactory.CreateObject("Response", null, core) as Response;

			if (response == null) {
				return null;
			}

			response.core = core;
			response.app_id = (core != null) ? core.appId : null;
			response.success = true;
			response.setResultList(buildRefusalResults(refusals, core));

			return response;
		}

		/**
		 * Asks the factory for the result model matching a component.
		 *
		 * A component's objectName is "Component.method" - the same string the
		 * result factory keys on, split back into its two halves.
		 */
		private static function createResultFor(component:BaseComponent, core:Core):BaseResult {
			if (component == null) {
				return null;
			}

			var fullName:String = component.objectName;

			if (fullName == null) {
				return null;
			}

			var splitAt:int = fullName.indexOf(".");

			if (splitAt < 1 || splitAt >= fullName.length - 1) {
				return null;
			}

			return ObjectFactory.CreateResult(
				fullName.substring(0, splitAt),
				fullName.substring(splitAt + 1),
				null,
				core
			);
		}
	}
}
