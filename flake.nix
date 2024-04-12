{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    perSystem = { pkgs, system, ... }: {
      packages.default = pkgs.writeShellScriptBin "stroke" ''
        ${pkgs.xdotool}/bin/xdotool type "$(${pkgs.xclip}/bin/xclip -o -selection clipboard)"
      '';
    };
  };
}
