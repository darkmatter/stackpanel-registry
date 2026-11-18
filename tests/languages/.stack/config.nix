{
  enable = true;
  name = "private-language-inputs";
  languages = {
    php = { enable = true; version = "7.4"; };
    ruby = { enable = true; version = "3.2.1"; };
    python = { enable = true; version = "3.11"; };
    zig = { enable = true; version = "0.15.1"; };
    solidity = { enable = true; foundry.enable = true; };
    terraform = { enable = true; version = "1.5.7"; };
  };
}
