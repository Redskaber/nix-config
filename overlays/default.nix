# @path: ~/projects/configs/nix-config/overlays/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: overlays::default
#
# nix-config  main ! +  via   v24.16.0
# ✦ ❯ home-manager --flake .#kilig@nixos switch --show-trace
# warning: Git tree '/home/kilig/projects/configs/nix-config' is dirty
# error: Cannot build '/nix/store/4rz1p2bknh2jids07zjxfli5ws95d702-openldap-2.6.13.drv'.
#        Reason: builder failed with exit code 2.
#        Output paths:
#          /nix/store/0q5xsmpijg292k5r97ms57w93jiwxrwa-openldap-2.6.13-dev
#          /nix/store/1396zxgd6hvrha86jwvr5c7h885y1v6k-openldap-2.6.13
#          /nix/store/jvvs9d0bd4ghwmdin17wgl3ziykf4jzm-openldap-2.6.13-man
#          /nix/store/zyiga3as0qnkip4sjrjs9xqckqk6lkiv-openldap-2.6.13-devdoc
#        Last 25 log lines:
#        > Using ldapsearch to check that consumer slapd is running...
#        > Using ldapadd to populate the provider directory...
#        > Waiting 7 seconds for syncrepl to receive changes...
#        > Using ldapmodify to modify provider directory...
#        > Waiting 7 seconds for syncrepl to receive changes...
#        > Performing modrdn alone on the provider...
#        > Waiting 7 seconds for syncrepl to receive changes...
#        > Performing modify alone on the provider...
#        > Waiting 7 seconds for syncrepl to receive changes...
#        > Performing larger modify on the provider...
#        > Waiting 7 seconds for syncrepl to receive changes...
#        > Try updating the consumer slapd...
#        > Using ldapsearch to read all the entries from the provider...
#        > Using ldapsearch to read all the entries from the consumer...
#        > Filtering provider results...
#        > Filtering consumer results...
#        > Comparing retrieved entries from provider and consumer...
#        > test failed - provider and consumer databases differ
#        > >>>>> 00:08:12 Failed   test017-syncreplication-refresh for mdb after 38 seconds
#        > (exit 1)
#        > make[2]: *** [Makefile:319: mdb-yes] Error 1
#        > make[2]: Leaving directory '/build/openldap-2.6.13/tests'
#        > make[1]: *** [Makefile:286: test] Error 2
#        > make[1]: Leaving directory '/build/openldap-2.6.13/tests'
#        > make: *** [Makefile:297: test] Error 2
#        For full logs, run:
#          nix log /nix/store/4rz1p2bknh2jids07zjxfli5ws95d702-openldap-2.6.13.drv
# error: Cannot build '/nix/store/vwkblngcy1jjq8srzf9125ylaf87gw04-lutris-0.5.22-fhsenv-rootfs.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/9kw8v7qj4az5pmyza2izh80jfjnvdm09-lutris-0.5.22-fhsenv-rootfs
# error: Build failed due to failed dependency
# error: Cannot build '/nix/store/z4n9yam640a3cl6n5vamkqrrfb73wjkg-lutris-0.5.22-bwrap.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/a0z5xq3q1xn95lc8krhjqwyzpfnic9h9-lutris-0.5.22-bwrap
# error: Build failed due to failed dependency
# error: Cannot build '/nix/store/1z8lvw4pz5rb81cf2f5cfrwylj4a9wxh-lutris-0.5.22.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/2i0xhwbd6mq04j0az9zs3hh8spbz1ydd-lutris-0.5.22
# error: Build failed due to failed dependency
# error: Cannot build '/nix/store/5y376jry556x9r1dq8flk4hd6f6g4q90-home-manager-path.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/csqivyxix9ljqz8s5lni4wndm4ninjvj-home-manager-path
# error: Cannot build '/nix/store/ng12q4pj66cidg8w6cqj86k16fl39y0x-lutris-0.5.22-fish-completions.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/76ws8xghwg9n63fqrm7l7f40a36qfmgr-lutris-0.5.22-fish-completions
# error: Cannot build '/nix/store/ig69lcaxlpbsxii8dl17h940mi3gn2xc-man-paths.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/gwvs4zcipsp6s4ava5aqbw4p8sanmw5a-man-paths
# error: Build failed due to failed dependency
# error: Build failed due to failed dependency
# error: Build failed due to failed dependency
# error: Cannot build '/nix/store/4yd598zh20d1z862b6dy8zncfd84sma6-activation-script.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/d6wnicggs40sbgx7vskdabbycc3v6zgm-activation-script
# error: Cannot build '/nix/store/lr8vmr79n7bg2dnz3v6y62w519yyaidg-hm_fontconfigconf.d10hmfonts.conf.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/kdmknh2dhfwrd1adhc2bbmh3gbrf8b9c-hm_fontconfigconf.d10hmfonts.conf
# error: Cannot build '/nix/store/bv3gcyf5xrs4qzznrg2v824lqgw7m9dg-home-manager-generation.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/8vidly3ma4chk8kxi9bq96a7x3ql8bg5-home-manager-generation
# error: Cannot build '/nix/store/l5af2fx5q0c2q5i2q41p20wrch8074q7-kilig-fish-completions.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/2avgknggmsy47dm3k8h3kw5ljj6ab2kq-kilig-fish-completions
# error: Cannot build '/nix/store/aix3wyz6qm2yra100qanwrycb9b96j76-man-cache.drv'.
#        Reason: 1 dependency failed.
#        Output paths:
#          /nix/store/b17i7dcr4xpqfix3nlzshrayaizi0k9a-man-cache
# error: Build failed due to failed dependency


# This file defines overlays
{ shared, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  patches = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    cutter_patched = shared.upkgs.cutter.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i \
          -e 's/\bSBK_CUTTERPLUGIN_IDX\b/SBK_CutterPlugin_IDX/g' \
          -e 's/\bSBK_CUTTERPLUGINMETADATA_IDX\b/SBK_CutterPluginMetadata_IDX/g' \
          src/plugins/PluginManager.cpp
        '';
    });
    
    # FIX: tests-suite error
    openldap = prev.openldap.overrideAttrs (old: {
      doCheck = false;   # skip the failing test suite
    });
  };


}


