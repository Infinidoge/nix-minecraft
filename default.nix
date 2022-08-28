(import (
  fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/b4a34015c698c7793d592d66adbab377907a2be8.tar.gz";
    sha256 = "0a1qndm9sf1q2cjhl9ziwd4cg9420x3n6wawvqpnxa0acvn7v999"; }
) {
  src =  ./.;
}).defaultNix
