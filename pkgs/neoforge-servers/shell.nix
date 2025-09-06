{
  mkShellNoCC,
  python3,
}:
mkShellNoCC {
  packages = [
    (python3.withPackages (
      ps: with ps; [
        packaging
        requests
        requests-cache
      ]
    ))
  ];
}
