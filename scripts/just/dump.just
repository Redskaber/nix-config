# Dump current project file tree + concat to stored/
dump:
  @mkdir -p tmp
  @bash scripts/sh/grep_paths.sh -l -e "*.sh" -e "*.just" -e "justfile" -x ".cache/*" -o tmp/scripts_paths.txt
  @bash scripts/sh/concat_files.sh tmp/scripts_paths.txt tmp/scripts.txt
  @bash scripts/sh/grep_paths.sh -l -e "*.md" -e "*.tmpl" -e "*.yaml" -x ".cache/*" -o tmp/docs_paths.txt
  @bash scripts/sh/concat_files.sh tmp/docs_paths.txt tmp/docs.txt
  @bash scripts/sh/grep_paths.sh -l -e "*.yml" -x ".cache/*" -o tmp/ci_cd_paths.txt
  @bash scripts/sh/concat_files.sh tmp/ci_cd_paths.txt tmp/ci_cd.txt
  @bash scripts/sh/grep_paths.sh -l -e "*.nix" -x ".cache/*" -o tmp/proj_paths.txt
  @bash scripts/sh/concat_files.sh tmp/proj_paths.txt tmp/proj.txt


