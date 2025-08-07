-- scripts/config/paths.lua
documents = app.getStandardPath("documents")
projects_root = app.joinPaths(documents, "limekit projects")
injection_dir = app.joinPaths(projects_root, ".limekit")
