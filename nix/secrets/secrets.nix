let
  laptop  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjyv0SQ5jU4P7V4HaBCf/m0OUT1bmHxrdZ0lJ2oV/Y0 root@laptop";
  desktop = "ssh-ed25519 REPLACE_WITH_DESKTOP_HOST_KEY root@desktop";
in {
  "openclaw.age".publicKeys = [ laptop desktop ];
}
