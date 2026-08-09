{
  description = "Hyprland dotfiles and configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.${system} or (import nixpkgs { inherit system; });
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "hyprland-dots";
            version = "0.1.0";
            src = ./.;
            installPhase = ''
              mkdir -p $out/share/hyprland-dots
              cp -r . $out/share/hyprland-dots
            '';
          };
        }
      );

      homeManagerModules.default = self.homeManagerModules.hyprland-dots;

      homeManagerModules.hyprland-dots = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.hyprland-dots;
        in
        {
          options.programs.hyprland-dots = {
            enable = lib.mkEnableOption "Hyprland dotfiles and packages";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              description = "The hyprland-dots package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = with pkgs; [
              awww
              grimblast
              hyprlock
              hyprpicker
              hyprshot
              grim
              slurp
              wl-screenrec
              gpu-screen-recorder
              wl-clip-persist
              wl-clipboard
              cliphist
              wf-recorder
              glib
              wayland
              direnv
              tesseract
            ];

            systemd.user.targets.hyprland-session.Unit.Wants = [
              "xdg-desktop-autostart.target"
            ];

            wayland.windowManager.hyprland = {
              enable = true;
              package = null;
              portalPackage = null;
              configType = "hyprlang";
              xwayland.enable = true;
              systemd.enable = true;
            };

            # Link dotfiles into ~/.config/hypr
            xdg.configFile."hypr".source = "${cfg.package}/share/hyprland-dots";
          };
        };
    };
}
