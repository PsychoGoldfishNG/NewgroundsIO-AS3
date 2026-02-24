package io.newgrounds.helpers {
	
	import io.newgrounds.models.objects.ObjectFactory;
	import io.newgrounds.models.objects.Response;
	import io.newgrounds.NGJSON;
	
	/**
	 * HttpResponseHelper
	 *
	 * Keeps HTTP response orchestration out of the Response model class.
	 *
	 * Responsibilities:
	 * - Import top-level response fields into Response
	 * - Convert raw result payloads into typed Result models
	 * - Propagate response-level error to result models when needed
	 * - Push typed results through AppState synchronization
	 *
	 * This preserves Response as a data model while Core controls I/O flow.
	 */
	public class HttpResponseHelper {
		
		public static function importResponseObject(responseModel:Response, jsonObject:Object):void {
			var hasResultProperty:Boolean = (jsonObject != null && jsonObject.hasOwnProperty("result"));
			var typedResults:* = null;
			
			var importObject:Object = cloneWithoutResult(jsonObject);
			responseModel.importFromObject(importObject);
			
			if (hasResultProperty) {
				typedResults = createTypedResults(jsonObject.result, responseModel.core);
				if (typedResults is Array) {
					responseModel.setResultList(typedResults as Array);
				} else if (typedResults != null) {
					responseModel.setResult(typedResults);
				} else {
					responseModel.setResult(null);
				}
			}
			
			propagateResponseError(responseModel);
			updateAppState(responseModel);
		}
		
		private static function cloneWithoutResult(source:Object):Object {
			var clone:Object = {};
			if (source == null) {
				return clone;
			}
			
			for (var key:String in source) {
				if (key != "result") {
					clone[key] = source[key];
				}
			}
			
			return clone;
		}
		
		private static function createTypedResults(rawResults:*, core:*):* {
			if (rawResults == null) {
				return null;
			}
			
			if (rawResults is Array) {
				var resultList:Array = [];
				for each (var rawResult:Object in rawResults) {
					var typedResult:* = createSingleTypedResult(rawResult, core);
					if (typedResult != null) {
						resultList.push(typedResult);
					}
				}
				return (resultList.length > 0) ? resultList : null;
			}
			
			return createSingleTypedResult(rawResults, core);
		}
		
		private static function createSingleTypedResult(rawResult:*, core:*):* {
			if (rawResult == null || !rawResult.hasOwnProperty("component") || !rawResult.hasOwnProperty("data")) {
				return null;
			}

			var componentPath:String = String(rawResult.component);
			var dotIndex:int = componentPath.indexOf(".");
			if (dotIndex <= 0 || dotIndex >= componentPath.length - 1) {
				return null;
			}
			
			var componentName:String = componentPath.substring(0, dotIndex);
			var methodName:String = componentPath.substring(dotIndex + 1);
			
			return ObjectFactory.CreateResult(componentName, methodName, rawResult.data, core);
		}
		
		private static function propagateResponseError(responseModel:Response):void {
			if (responseModel.error == null) {
				return;
			}
			
			if (responseModel.resultIsList()) {
				for each (var resultModel:* in responseModel.getResultList()) {
					if (resultModel != null && resultModel.error == null) {
						resultModel.error = responseModel.error;
					}
				}
			} else if (responseModel.getResult() != null && responseModel.getResult().error == null) {
				responseModel.getResult().error = responseModel.error;
			}
		}
		
		private static function updateAppState(responseModel:Response):void {
			if (responseModel.core == null || responseModel.core.appState == null) {
				return;
			}
			
			if (responseModel.resultIsList()) {
				for each (var resultModel:* in responseModel.getResultList()) {
					responseModel.core.appState.setValueFromResult(resultModel);
				}
			} else if (responseModel.getResult() != null) {
				responseModel.core.appState.setValueFromResult(responseModel.getResult());
			}
		}
	}
}
