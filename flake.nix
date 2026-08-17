{
  description = "Display Typst content in Markdown and Org";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs systems (system: function nixpkgs.legacyPackages.${system});
      mkPlugin =
        pkgs:
        pkgs.vimUtils.buildVimPlugin {
          pname = "typst-infect";
          version = "0-unstable-2026-08-17";
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./lua
              ./plugin
              ./queries
            ];
          };
          meta = {
            license = pkgs.lib.licenses.mit;
            description = "Display Typst content in Markdown and Org";
            platforms = pkgs.lib.platforms.all;
            sourceProvenance = [ pkgs.lib.sourceTypes.fromSource ];
          };
        };
      nixvimModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        lib.nixvim.plugins.mkNeovimPlugin {
          name = "typst-infect";
          package = lib.mkOption {
            type = lib.types.package;
            default = mkPlugin pkgs;
            defaultText = lib.literalExpression "typst-infect package from the flake";
            description = "The typst-infect package to use.";
          };
          description = "Display Typst content in Markdown and Org";
          maintainers = [ ];

          settingsOptions = {
            markdown = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.attrsOf lib.nixvim.lua-types.anything;
              };
              default = {
                enabled = true;
              };
              description = "Markdown integration settings passed to typst-infect.";
            };

            org = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.attrsOf lib.nixvim.lua-types.anything;
              };
              default = {
                enabled = false;
                variants = {
                  inline = true;
                  display = true;
                  latex_env = false;
                  equation_block = false;
                  src_blocks = [
                    "typst"
                    "typst_math"
                    "math"
                  ];
                };
              };
              description = "Org integration settings passed to typst-infect.";
            };
          };

          extraPackages = [
            pkgs.ghostscript
            pkgs.imagemagick
            pkgs.typst
          ];

          extraConfig = _: {
            plugins.snacks.enable = lib.mkDefault true;
            plugins.snacks.settings.image.enabled = lib.mkDefault true;
            plugins.orgmode.enable = lib.mkDefault config.plugins.typst-infect.settings.org.enabled;
            plugins.treesitter.enable = lib.mkDefault true;
            plugins.treesitter.grammarPackages = lib.mkAfter (
              with config.plugins.treesitter.package.builtGrammars;
              [
                markdown
                markdown_inline
                typst
              ]
            );
          };
        };
    in
    {
      overlays.default = final: previous: {
        vimPlugins = previous.vimPlugins // {
          typst-infect = mkPlugin final;
        };
      };

      nixvimModules.default = nixvimModule;

      packages = forAllSystems (pkgs: rec {
        typst-infect = mkPlugin pkgs;
        default = typst-infect;
      });

      checks = forAllSystems (pkgs: {
        overlay = (pkgs.extend self.overlays.default).vimPlugins.typst-infect;
        nixvim-module =
          nixvim.lib.${pkgs.stdenv.hostPlatform.system}.check.mkTestDerivationFromNixvimModule
            {
              inherit pkgs;
              module = {
                imports = [ self.nixvimModules.default ];
                plugins.typst-infect = {
                  enable = true;
                  settings = {
                    markdown = {
                      enabled = true;
                      testVariant = "freeform";
                    };
                    org = {
                      enabled = true;
                      variants = {
                        src_blocks = [
                          "typst"
                          "typst_math"
                          "math"
                        ];
                        testVariant = "freeform";
                      };
                    };
                  };
                };
              };
            };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            just
            lua-language-server
            nixfmt
            stylua
            typst
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
