{
  description = "Modular Lua-powered Hyprland Desktop Environment Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      homeManagerModule = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.hyprland-dots;
        in {
          options.programs.hyprland-dots = {
            enable = lib.mkEnableOption "Modular Lua-driven Hyprland configuration";
            targetDir = lib.mkOption {
              type = lib.types.str;
              default = "hypr";
              description = "Target path relative to ~/.config where the hyprland configuration will be linked.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = with pkgs; [
              hyprland
              hyprlock
              hyprpicker
              hyprshot
              fuzzel
              wl-clipboard
              cliphist
              wl-clip-persist
              playerctl
              brightnessctl
              wireplumber
              pamixer
              grim
              slurp
              tesseract
              gpu-screen-recorder
              wl-screenrec
              jq
              libnotify
              luajit
            ];

            xdg.configFile."${cfg.targetDir}" = {
              source = ./.;
              recursive = true;
            };
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        installer = pkgs.writeShellApplication {
          name = "hyprland-dots-install";
          runtimeInputs = with pkgs; [ git coreutils ];
          text = ''
            CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
            echo ":: Installing Hyprland dotfiles to $CONFIG_DIR..."
            if [ -d "$CONFIG_DIR" ]; then
              BACKUP_DIR="''${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
              echo ":: Backing up existing config to $BACKUP_DIR"
              mv "$CONFIG_DIR" "$BACKUP_DIR"
            fi
            mkdir -p "$CONFIG_DIR"
            cp -r ${./.}/* "$CONFIG_DIR/"
            chmod -R +w "$CONFIG_DIR"
            echo ":: Installation complete! You can now start or reload Hyprland."
          '';
        };

        dotfilesPkg = pkgs.stdenv.mkDerivation {
          pname = "hyprland-dots";
          version = "1.0.0";
          src = ./.;
          installPhase = ''
            mkdir -p $out/share/hyprland-dots
            cp -r . $out/share/hyprland-dots
          '';
        };
      in
      {
        packages = {
          default = dotfilesPkg;
          hyprland-dots = dotfilesPkg;
          install = installer;
        };

        devShells.default = pkgs.mkShell {
          name = "hyprland-dots-dev";
          packages = with pkgs; [
            hyprland
            hyprlock
            hyprpicker
            hyprshot
            fuzzel
            wl-clipboard
            cliphist
            playerctl
            brightnessctl
            wireplumber
            pamixer
            grim
            slurp
            tesseract
            wl-screenrec
            jq
            libnotify
            luajit
            stylua
            luacheck
          ];

          shellHook = ''
            echo "🌌 Hyprland Dotfiles Flake Development Environment"
            echo "Run 'stylua .' to format Lua files or check scripts in hyprland/scripts/"
          '';
        };
      }
    ) // {
      homeManagerModules = {
        default = homeManagerModule;
        hyprland-dots = homeManagerModule;
      };
    };
}
