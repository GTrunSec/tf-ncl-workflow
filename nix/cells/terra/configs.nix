{ inputs, cell }:
{
  ex = cell.lib.mkTerra (
    # this file will be removed and provided by a module
    { config, lib, ... }:

    with lib;

    let

      cfg = config.github;

      default_token = "github_api_token";
    in
    {

      options.github = {
        enable = mkEnableOption "enable github provider";

        provider = mkOption {
          default = {
            token = "\${ var.${default_token} }";
          };
          type =
            with types;
            (submodule {
              options = {
                token = mkOption {
                  type = with types; str;
                  default = "\${ var.${default_token} }";
                  description = ''
                    login token
                  '';
                };
              };
            });
        };
      };

      config = mkMerge [
        {github.enable = true;}
        (mkIf cfg.enable { provider.github = cfg.provider; })

        (mkIf (cfg.enable && cfg.provider.token == "\${ var.${default_token} }") {
          variable."${default_token}" = {
            description = ''
              github token
            '';
          };
        })
      ];
    }
  );
}
