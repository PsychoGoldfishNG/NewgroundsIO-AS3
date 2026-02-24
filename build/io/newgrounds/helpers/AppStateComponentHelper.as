package io.newgrounds.helpers {
	
	import io.newgrounds.Core;
	import io.newgrounds.BaseComponent;
	import io.newgrounds.models.objects.ObjectFactory;
	
	/**
	 * AppStateComponentHelper
	 *
	 * Maps AppState property names to the component calls required to load them.
	 */
	public class AppStateComponentHelper {
		
		/**
		 * Builds the list of components needed to load requested AppState properties.
		 */
		public static function buildComponentsForProperties(propertyNames:Array, core:Core, host:String):Array {
			var components:Array = [];
			
			for each (var propertyName:String in propertyNames) {
				var component:BaseComponent = null;
				
				switch (propertyName) {
					case "gatewayVersion":
						component = ObjectFactory.CreateComponent("Gateway", "getVersion", null, core);
						break;
					
					case "currentVersion":
						component = ObjectFactory.CreateComponent("App", "getCurrentVersion", null, core);
						if (component != null) {
							component["version"] = core.buildVersion;
						}
						break;
					
					case "hostApproved":
						component = ObjectFactory.CreateComponent("App", "getHostLicense", null, core);
						if (component != null) {
							component["host"] = host;
						}
						break;
					
					case "saveSlots":
						component = ObjectFactory.CreateComponent("CloudSave", "loadSlots", null, core);
						break;
					
					case "medals":
						component = ObjectFactory.CreateComponent("Medal", "getList", null, core);
						break;
					
					case "medalScore":
						component = ObjectFactory.CreateComponent("Medal", "getMedalScore", null, core);
						break;
					
					case "scoreBoards":
						component = ObjectFactory.CreateComponent("ScoreBoard", "getBoards", null, core);
						break;
				}
				
				if (component != null) {
					components.push(component);
				}
			}
			
			return components;
		}
	}
}
