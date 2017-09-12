{ lib, bundlerEnv, ruby, stdenv, polipo, graphviz, python, qemu}:
let
  version = "2.9.0";
  mygems = bundlerEnv {
    name = "kameleon-builder-${version}-gems";
    inherit ruby;
    gemdir = ./.;
  };
in stdenv.mkDerivation rec {
  name = "kameleon";
  buildInputs = [ mygems ruby polipo graphviz python qemu ];

  entrypoint = ./bin/kameleon;

  installCommand = ''
    mkdir -p $out/bin
    install -D -m755 ${entrypoint} $out/bin/kameleon
  '';
   meta = with lib; {
    description = "The mindful appliance builder";
    homepage    = http://kameleon.imag.fr/;
    license     = with licenses; gpl2;
    #maintainers = with maintainers; [ #TODO ];
    platforms   = platforms.unix;
  };
}
