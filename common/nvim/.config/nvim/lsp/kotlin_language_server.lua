return {
	cmd = { "kotlin-language-server" },
	cmd_env = {
		-- The system default is Java 8, but kotlin-language-server requires 11+.
		JAVA_HOME = "/usr/lib/jvm/java-17-openjdk",
		PATH = "/usr/lib/jvm/java-17-openjdk/bin:" .. (vim.env.PATH or ""),
	},
	filetypes = { "kotlin" },
	root_markers = {
		"settings.gradle",
		"settings.gradle.kts",
		"build.gradle",
		"build.gradle.kts",
		"gradlew",
		"pom.xml",
		".git",
	},
	single_file_support = true,
}
