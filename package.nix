{ rustPlatform
, fetchFromGitHub
, lib
}:

rustPlatform.buildRustPackage (finalAttrs: {
	pname = "feedlynx";
	version = "0.4.0";

	src = fetchFromGitHub {
		owner = "wezm";
		repo = "feedlynx";
		tag = finalAttrs.version;
		hash = "sha256-w+ZSFw1DGAb4OQT45/BpVo4AoxKZnwnX/6oZZ8gb9Z0=";
	};

	cargoHash = "sha256-ZiMWXtDVt/Je8pLyqWCN8SHXG3KzbBHxeacqUBVzWw0=";

	meta = {
		description = "Collect links to read or watch later in your RSS reader.";
		homepage = "https://github.com/wezm/feedlynx";
		mainProgram = "feedlynx";
	};
})
