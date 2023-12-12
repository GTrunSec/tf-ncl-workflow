{inputs, cell}:
let
  inherit (inputs) tf-ncl nickel;
  l = inputs.nixpkgs.lib // builtins;
  writeShellApplication = inputs.omnibus.ops.writeShellApplication {
    inherit (inputs) nixpkgs;
  };
in
{
  mkTfCommand =
    name: nixpkgs: tfPlugins: git:
    let
      terraform-with-plugins = nixpkgs.terraform.withPlugins (
        p: nixpkgs.lib.attrValues (tfPlugins p)
      );
      ncl-schema = tf-ncl.generateSchema tfPlugins;
    in
    writeShellApplication {
      inherit name;
      runtimeEnv = {
        TF_IN_AUTOMATION = 1;
        TF_PLUGIN_CACHE_DIR = "$PRJ_CACHE_HOME/tf-plugin-cache";
      };
      runtimeInputs = with inputs.nixpkgs; [
        nickel.packages.default
        terraform-with-plugins
        terraform-backend-git
      ];
      text = ''
        set -e

        if [[ ! -d "$PRJ_DATA_DIR"/tf-ncl/${name} ]]; then
           mkdir -p "$PRJ_DATA_DIR"/tf-ncl/${name}
           mkdir -p "$PRJ_CACHE_HOME"/tf-plugin-cache
        fi

        if [[ "$#" -le 1 ]]; then
          echo "terraform <ncl-file> ..."
          exit 1
        fi
        ENTRY="''${1}"
        shift
        ln -snfT ${ncl-schema} "$PRJ_DATA_DIR"/tf-ncl/${name}/schema.ncl
        nickel export > "$PRJ_DATA_DIR"/tf-ncl/${name}/main.tf.json <<EOF
          (import "''${ENTRY}").renderable_config
        EOF

        ${if git != {} then
          ''
            ENTRY_DIR="$(dirname "$ENTRY")"

            terraform-backend-git git \
               --dir "$PRJ_DATA_DIR"/tf-ncl/${name} \
               --repository ${git.repo} \
               --ref ${git.ref} \
               --state "''${ENTRY_DIR}/state.json" \
               terraform "$@"
          ''
        else
          ''
            terraform -chdir="$PRJ_DATA_DIR"/tf-ncl/${name} "$@"
          ''}
      '';
    };
}
