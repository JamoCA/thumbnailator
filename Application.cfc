component {
	this.name = "thumbnailator-demo";
	this.sessionManagement = false;

	variables.appDir = getDirectoryFromPath(getCurrentTemplatePath());

	this.mappings = {};

	variables.jarPath = getEnv("THUMBNAILATOR_JAR_PATH", "");
	variables.jarDir  = getEnv("THUMBNAILATOR_JAR_DIR", "");

	variables.paths = resolveJarPaths(variables.jarPath, variables.jarDir, variables.appDir & "lib/thumbnailator/");

	this.javaSettings = [
		"loadPaths":      variables.paths,
		"reloadOnChange": false
	];

	private array function resolveJarPaths(required string jarPath, required string jarDir, required string bundledDir)
			hint="Resolve a list of JAR file paths from env override or bundled fallback. Returns explicit file paths so BoxLang's classloader (which does not scan directories) can find them." {
		var paths = [];
		if (len(arguments.jarPath) && fileExists(arguments.jarPath)) {
			arrayAppend(paths, arguments.jarPath);
			return paths;
		}
		var dir = (len(arguments.jarDir) && directoryExists(arguments.jarDir)) ? arguments.jarDir : arguments.bundledDir;
		if (!directoryExists(dir)) return paths;
		var jars = directoryList(dir, false, "path", "*.jar");
		for (var j in jars) arrayAppend(paths, j);
		return paths;
	}

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
