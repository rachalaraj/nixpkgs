{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.caelestia-shell;
in
{
  options.programs.caelestia-shell = {
    enable = lib.mkEnableOption "caelestia-shell, a fluid, morphing desktop shell for Wayland";

    package = lib.mkPackageOption pkgs "caelestia-shell" { };

    resizer.enable = lib.mkEnableOption "the caelestia window resizer daemon service";

    cursor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to install and set Bibata-Caelestia as the default cursor theme.
        '';
      };

      package = lib.mkPackageOption pkgs "bibata-caelestia" { };

      theme = lib.mkOption {
        type = lib.types.str;
        default = "Bibata-Caelestia";
        description = ''
          The cursor theme name to set in fallback themes and session variables.
        '';
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = ''
          Default cursor size.
        '';
      };
    };

    portal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to configure xdg-desktop-portal and add xdg-desktop-portal-wormhole as an extra portal for Caelestia Shell.
        '';
      };

      package = lib.mkPackageOption pkgs "xdg-desktop-portal-wormhole" { };
    };

    recommendedServices = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable recommended services and integrations used by Caelestia's widgets
          (Hyprland, NetworkManager, PipeWire, GeoClue2, UPower, Power Profiles Daemon, Accounts Daemon,
          GNOME Keyring, Bluetooth, I2C, and GPU Screen Recorder).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [
          cfg.package
          pkgs.caelestia-cli
          pkgs.procps
        ]
        ++ lib.optional cfg.cursor.enable cfg.cursor.package
        ++ lib.optionals cfg.recommendedServices.enable [
          pkgs.swappy
          pkgs.grim
          pkgs.slurp
          pkgs.cliphist
          pkgs.wl-clipboard
          pkgs.polkit_gnome
          pkgs.gammastep
          pkgs.trash-cli
          pkgs.hyprpicker
        ];

        xdg.icons.fallbackCursorThemes = lib.mkIf cfg.cursor.enable (lib.mkDefault [ cfg.cursor.theme ]);

        environment.sessionVariables = lib.mkIf cfg.cursor.enable {
          XCURSOR_THEME = lib.mkDefault cfg.cursor.theme;
          XCURSOR_SIZE = lib.mkDefault (toString cfg.cursor.size);
          HYPRCURSOR_THEME = lib.mkDefault cfg.cursor.theme;
          HYPRCURSOR_SIZE = lib.mkDefault (toString cfg.cursor.size);
        };

        xdg.portal = lib.mkIf cfg.portal.enable {
          enable = lib.mkDefault true;
          extraPortals = [
            cfg.portal.package
            pkgs.xdg-desktop-portal-gtk
          ];
          configPackages = [ cfg.portal.package ];
        };

        fonts.packages = with pkgs; [
          material-symbols
          rubik
          nerd-fonts.caskaydia-cove
          nerd-fonts.jetbrains-mono
        ];

        hardware.graphics.enable = lib.mkDefault true;

        security = {
          polkit.enable = lib.mkDefault true;
          rtkit.enable = lib.mkDefault true;
        };

        systemd.user.services = {
          caelestia-shell = {
            description = "Caelestia Shell Wayland desktop UI";
            documentation = [ "https://github.com/caelestia-dots/shell" ];
            partOf = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];
            after = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];
            wantedBy = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];

            serviceConfig = {
              Type = "exec";
              ExecStart = lib.getExe cfg.package;
              Restart = "on-failure";
              RestartSec = "5s";
              TimeoutStopSec = "5s";
              Slice = "session.slice";
            };

            environment = {
              QT_QPA_PLATFORM = "wayland";
            };
          };

          caelestia-resizer = lib.mkIf cfg.resizer.enable {
            description = "Caelestia window resizer daemon";
            documentation = [ "https://github.com/caelestia-dots/cli" ];
            partOf = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];
            after = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];
            wantedBy = [
              "graphical-session.target"
              "wayland-session@Hyprland.target"
            ];

            serviceConfig = {
              Type = "exec";
              ExecStart = "${lib.getExe pkgs.caelestia-cli} resizer";
              Restart = "on-failure";
              RestartSec = "5s";
              TimeoutStopSec = "5s";
            };
          };
        };
      }

      (lib.mkIf cfg.recommendedServices.enable {
        programs.hyprland.enable = lib.mkDefault true;
        programs.gpu-screen-recorder.enable = lib.mkDefault true;

        hardware = {
          bluetooth.enable = lib.mkDefault true;
          i2c.enable = lib.mkDefault true;
        };

        networking.networkmanager.enable = lib.mkDefault true;
        location.provider = lib.mkDefault "geoclue2";

        services = {
          upower.enable = lib.mkDefault true;
          power-profiles-daemon.enable = lib.mkDefault true;
          accounts-daemon.enable = lib.mkDefault true;
          gnome.gnome-keyring.enable = lib.mkDefault true;
          geoclue2 = {
            enable = lib.mkDefault true;
            enableDemoAgent = lib.mkDefault true;
            appConfig.gammastep = {
              isAllowed = true;
              isSystem = true;
            };
          };
          pipewire = {
            enable = lib.mkDefault true;
            pulse.enable = lib.mkDefault true;
          };
        };
      })
    ]
  );

  meta.maintainers = with lib.maintainers; [
    rachalaraj
  ];
}
