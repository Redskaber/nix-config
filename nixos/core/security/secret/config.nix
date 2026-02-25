# @path: ~/projects/configs/nix-config/nixos/core/security/secret/config.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security::secret::config


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    # 指定age密钥文件 - 使用您的SSH主机密钥
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # 默认的sops文件
    defaultSopsFile = ../../../../secrets/secrets.yaml;

    # 配置要解密的秘密
    secrets."users/kilig/terminal_pwd" = {
      # 设置权限
      owner = "kilig";
      group = "users";
      mode = "0400";  # 仅所有者可读

      # 如需服务重启时更改秘密
      # restartUnits = [ "your-service.service" ];

      # 或创建指向特定位置的符号链接
      # path = "/home/kilig/.config/terminal_pwd";
    };
  };

}


