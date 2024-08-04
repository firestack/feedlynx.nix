{ lib
, config
, pkgs
, ...
}: let
	cfg = config.services.feedlynx;
in {
	options.services.feedlynx = {
		enable = lib.mkEnableOption "FeedLynx";

		package = lib.mkPackageOption pkgs "feedlynx" {};

		address = lib.mkOption {
			default = "localhost";
			type = lib.types.str;
		};

		port = lib.mkOption {
			default = 41080;
			type = lib.types.port;
		};

		feed_path = lib.mkOption {
			default = "feed.xml";
		};

		feed_token = lib.mkOption {
			type = lib.types.str;
		};

		private_token = lib.mkOption {
			type = lib.types.str;
		};
	};

	config = lib.mkIf cfg.enable {
		users.users.feedlynx = {
			home            = "/var/lib/feedlynx";
			createHome      = true;
			isSystemUser    = true;
			group = "feedlynx";
		};
		users.groups.feedlynx = {};

		systemd.services.feedlynx = {
			wantedBy = [ "multiuser.target" ];
			wants = [ "network-online.target" ];
			description = "FeedLynx, Server to Collect links in your RSS reader.";

			environment = lib.mkMerge [
				{
					FEEDLYNX_FEED_TOKEN = cfg.feed_token;
					FEEDLYNX_PRIVATE_TOKEN = cfg.private_token;
				}
				(lib.mkIf (cfg.address != null) { FEEDLYNX_ADDRESS = cfg.address; })
				(lib.mkIf (cfg.port != null) { FEEDLYNX_PORT = toString cfg.port; })
			];

			serviceConfig = {
				ExecStart = "${lib.getExe cfg.package} ${cfg.feed_path}";
				Restart = "always";
				User = "feedlynx";
				WorkingDirectory = config.users.users.feedlynx.home;
			};
		};
	};
}

