package io.newgrounds.helpers {
	
	import io.newgrounds.BaseComponent;
	import io.newgrounds.Core;
	import io.newgrounds.models.objects.Execute;
	
	/**
	 * CoreQueueExecutionHelper
	 *
	 * Splits queued Execute wrappers into:
	 * - redirect components (executed individually)
	 * - batchable execute wrappers (sent in one request)
	 */
	public class CoreQueueExecutionHelper {
		
		/**
		 * Partitions Core's execute queue for redirect-vs-batch dispatch.
		 */
		public static function partitionExecuteQueue(componentQueue:Array, core:Core):Object {
			var redirectComponents:Array = [];
			var batchedExecuteWrappers:Array = [];
			
			for each (var executeWrapper:Execute in componentQueue) {
				var componentModel:BaseComponent = executeWrapper.componentModel;
				var redirect:Boolean = (componentModel != null && componentModel.redirect) ? componentModel.redirect : false;
				
				if (redirect === true) {
					redirectComponents.push(componentModel);
					continue;
				}
				
				executeWrapper.core = core;
				batchedExecuteWrappers.push(executeWrapper);
			}
			
			return {
				redirectComponents: redirectComponents,
				batchedExecuteWrappers: batchedExecuteWrappers
			};
		}
	}
}
