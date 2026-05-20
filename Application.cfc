component {
	this.name = "thumbnailator-demo";
	this.sessionManagement = false;

	variables.appDir = getDirectoryFromPath(getCurrentTemplatePath());

	this.mappings = {};

	variables.jarPath = getEnv("THUMBNAILATOR_JAR_PATH", "");
	variables.jarDir  = getEnv("THUMBNAILATOR_JAR_DIR", "");

	variables.paths = [];
	if (len(variables.jarPath) && fileExists(variables.jarPath)) {
		arrayAppend(variables.paths, variables.jarPath);
	} else if (len(variables.jarDir) && directoryExists(variables.jarDir)) {
		arrayAppend(variables.paths, variables.jarDir);
	} else {
		arrayAppend(variables.paths, variables.appDir & "lib/thumbnailator/");
	}

	this.javaSettings = [
		"loadPaths":      variables.paths,
		"reloadOnChange": false
	];

	private string function getEnv(required string name, string defaultValue = "")
			hint="Reads system property then env var with fallback" {
		var sys = createObject("java", "java.lang.System");
		var val = sys.getProperty(javacast("string", arguments.name));
		if (!isnull(val) && len(val)) return val;
		val = sys.getenv(javacast("string", arguments.name));
		if (!isnull(val) && len(val)) return val;
		return arguments.defaultValue;
	}
}
