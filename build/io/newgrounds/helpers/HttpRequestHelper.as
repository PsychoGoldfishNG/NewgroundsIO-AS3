package io.newgrounds.helpers {
	
	import flash.errors.IllegalOperationError;
	import io.newgrounds.models.objects.Execute;
	import io.newgrounds.models.objects.Request;
	
	/**
	 * HttpRequestHelper
	 *
	 * Keeps HTTP request serialization/encryption logic out of Request/Execute model classes.
	 *
	 * Responsibilities:
	 * - Build API-ready request payloads from Request container models
	 * - Normalize execute single-vs-array representation
	 * - Format Execute items for gateway transmission
	 * - Apply secure Execute encryption when required
	 */
	public class HttpRequestHelper {
		
		public static function buildGatewayRequestObject(requestModel:Request):Object {
			var requestObject:Object = {
				app_id: requestModel.app_id
			};
			
			if (requestModel.session_id != null) {
				requestObject.session_id = requestModel.session_id;
			}
			
			if (requestModel.debug === true) {
				requestObject.debug = true;
			}
			
			if (requestModel.echo != null) {
				requestObject.echo = requestModel.echo;
			}
			
			requestObject.execute = serializeExecuteValue(requestModel);
			return requestObject;
		}
		
		private static function serializeExecuteValue(requestModel:Request):* {
			if (requestModel.executeIsArray()) {
				var executeArray:Array = [];
				for each (var item:* in requestModel.getExecuteList()) {
					executeArray.push(serializeExecuteItem(item));
				}
				return executeArray;
			}
			
			if (requestModel.getExecute() != null) {
				return serializeExecuteItem(requestModel.getExecute());
			}
			
			return null;
		}
		
		private static function serializeExecuteItem(executeItem:*):* {
			if (executeItem is Execute) {
				return serializeExecute(executeItem as Execute);
			}
			
			if (executeItem != null && executeItem.hasOwnProperty("toObject")) {
				return executeItem.toObject();
			}
			
			return executeItem;
		}
		
		private static function serializeExecute(executeModel:Execute):Object {
			var executeObject:Object = {
				component: executeModel.component,
				parameters: executeModel.parameters
			};
			
			if (executeModel.componentModel != null && executeModel.componentModel.isSecure) {
				if (executeModel.core == null) {
					throw new IllegalOperationError("Core is required for encrypting secure components.");
				}
				
				var encryptedObject:String = executeModel.core.encryptObject(executeObject);
				return { secure: encryptedObject };
			}
			
			return executeObject;
		}
	}
}
