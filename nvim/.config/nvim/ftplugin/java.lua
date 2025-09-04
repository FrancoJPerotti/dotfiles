local jdtls = require("jdtls")
local base_capabilities = vim.lsp.protocol.make_client_capabilities()
local capabilities = require("cmp_nvim_lsp").default_capabilities(base_capabilities)

local home = os.getenv("HOME")
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = home .. "/.local/share/nvim/jdtls-workspaces/" .. project_name

local config = {
	cmd = {
		"/usr/lib/jvm/java-21-openjdk/bin/java",
		"-Declipse.application=org.eclipse.jdt.ls.core.id1",
		"-Dosgi.bundles.defaultStartLevel=4",
		"-Declipse.product=org.eclipse.jdt.ls.core.product",
		"-Dlog.protocol=true",
		"-Dlog.level=ALL",
		"-Xms1g",
		"--add-modules=ALL-SYSTEM",
		"--add-opens",
		"java.base/java.util=ALL-UNNAMED",
		"--add-opens",
		"java.base/java.lang=ALL-UNNAMED",
		"-jar",
		vim.fn.glob(home .. "/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
		"-configuration",
		home .. "/.local/share/nvim/mason/packages/jdtls/config_linux",
		"-data",
		workspace_dir,
	},

	root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),

	capabilities = capabilities,

	settings = {
		java = {
			configuration = {
				runtimes = {
					{
						name = "JavaSE-1.8",
						path = "/usr/lib/jvm/java-8-openjdk",
					},
				},
			},
		},
	},

	init_options = {
		bundles = {},
	},
}

-- config.on_init = function(client, _)
-- 	vim.notify("JDTLS initialized with capabilities:\n" .. vim.inspect(client.server_capabilities), vim.log.levels.INFO)
-- end

local ok, err = pcall(jdtls.start_or_attach, config)
if not ok then
	vim.notify("jdtls failed: " .. tostring(err), vim.log.levels.ERROR)
end
