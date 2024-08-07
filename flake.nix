{
  description = "Build a cargo project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        inherit (pkgs) lib;

        craneLib = crane.mkLib pkgs;
        src = (pkgs.fetchFromGitHub {
          owner = "wezm";
          repo = "feedlynx";
          rev = "0.2.2";
          hash = "sha256-Z51W9aGSx6LKEft7nZ+oIpk10sF+vegkylJJOFIRQYU=";
        });

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;

          buildInputs = [
            # Add additional build inputs here
          ] ++ lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };

        craneLibLLvmTools = craneLib.overrideToolchain
          (fenix.packages.${system}.complete.withComponents [
            "cargo"
            "llvm-tools"
            "rustc"
          ]);

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        feedlynx = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          doCheck = false;
          # outputHashMode = "recursive";
          # outputHashAlgo = "sha256";
          # outputHash = lib.fakeHash;
          meta.mainProgram = "feedlynx";
        });
      in
      {
        checks = {
          # Build the crate as part of `nix flake check` for convenience
          inherit feedlynx;

          # Run clippy (and deny all warnings) on the crate source,
          # again, reusing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          feedlynx-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          feedlynx-doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          # Check formatting
          feedlynx-fmt = craneLib.cargoFmt {
            inherit src;
          };

          # Audit dependencies
          feedlynx-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # Audit licenses
          feedlynx-deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on `feedlynx` if you do not want
          # the tests to run twice
          feedlynx-nextest = craneLib.cargoNextest (commonArgs // {
            inherit cargoArtifacts;
            partitions = 1;
            partitionType = "count";
          });
        };

        packages = {
          default = feedlynx;
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          feedlynx-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (commonArgs // {
            inherit cargoArtifacts;
          });
        };

        apps.default = flake-utils.lib.mkApp {
          drv = feedlynx;
        };


        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = [
            # pkgs.ripgrep
          ];
        };
      }) // {

        nixosModules.default = ./nixos-module.nix;
    };
}
