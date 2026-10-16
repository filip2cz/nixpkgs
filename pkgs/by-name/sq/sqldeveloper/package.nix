{
  lib,
  stdenv,
  requireFile,
  makeWrapper,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  rpm,
  cpio,
  jdk17,
  # Runtime shell tools required by launcher.sh and sqldeveloper scripts
  bash,
  coreutils,
  file,
  findutils,
  gawk,
  gnugrep,
  gnused,
  which,
  # Runtime dependencies for bundled JavaFX and JNA native libraries
  alsa-lib,
  atk,
  cairo,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk2,
  gtk3,
  libdrm,
  libGL,
  libX11,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXinerama,
  libXrandr,
  libXrender,
  libXtst,
  libXxf86vm,
  mesa,
  pango,
  zlib,
}:

let
  runtimeLibs = [
    alsa-lib
    atk
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk2
    gtk3
    libdrm
    libGL
    libX11
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXrender
    libXtst
    libXxf86vm
    mesa
    pango
    zlib
  ];

  runtimeBins = [
    jdk17
    bash
    coreutils
    file
    findutils
    gawk
    gnugrep
    gnused
    which
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sqldeveloper";
  version = "26.2.0";

  src = requireFile {
    name = "sqldeveloper-${finalAttrs.version}-186.2220.noarch.rpm";
    url = "https://www.oracle.com/database/sqldeveloper/technologies/download/";
    hash = "sha256-8jZrdG9aQrQxRIywdga94cR8KDmMjX5092ZeZ1qz/e4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    cpio
    makeWrapper
    rpm
  ];

  buildInputs = runtimeLibs;

  # Binary distribution - no configure/build steps
  dontConfigure = true;
  dontBuild = true;

  # Explicit list of optional dependencies that are not provided or are dynamically
  # provided at runtime by the JVM / optional media subsystems
  autoPatchelfIgnoreMissingDeps = [
    "libjawt.so"
    "libjvm.so"
    "libavcodec*"
    "libavformat*"
    "libavutil*"
    "libgst*"
  ];

  unpackPhase = ''
    runHook preUnpack
    rpm2cpio "$src" | cpio -idm --quiet
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # --- Main application tree ---
    mkdir -p "$out/share/sqldeveloper" "$out/bin"
    cp -a opt/sqldeveloper/* "$out/share/sqldeveloper/"

    # Remove Windows executables and batch files
    find "$out/share/sqldeveloper" -name '*.bat' -delete
    find "$out/share/sqldeveloper" -name '*.exe' -delete

    # Ensure launcher scripts are executable
    chmod +x "$out/share/sqldeveloper/sqldeveloper.sh"
    chmod +x "$out/share/sqldeveloper/sqldeveloper/bin/sqldeveloper"
    chmod +x "$out/share/sqldeveloper/ide/bin/launcher.sh"

    # --- Patch main launcher script to point to store location ---
    substituteInPlace "$out/share/sqldeveloper/sqldeveloper.sh" \
      --replace-warn 'cd "`dirname $0`"/sqldeveloper/bin && bash sqldeveloper $*' \
                      'cd "'"$out"'/share/sqldeveloper/sqldeveloper/bin" && exec ./sqldeveloper "$@"'

    # --- Define missing Windows directives in launcher.sh to suppress harmless warnings ---
    substituteInPlace "$out/share/sqldeveloper/ide/bin/launcher.sh" \
      --replace-fail 'AddWindowsVMOption()' \
                     'AddWindowsVM11OrHigherOption() { :; }; AddWindowsVMOption()'

    # --- Configure JDK home in product jdk.conf ---
    echo "SetJavaHome ${jdk17.home}" >> "$out/share/sqldeveloper/sqldeveloper/bin/jdk.conf"

    # --- Wrapped binary in $out/bin ---
    makeWrapper "$out/share/sqldeveloper/sqldeveloper.sh" "$out/bin/sqldeveloper" \
      --set JAVA_HOME "${jdk17.home}" \
      --prefix PATH : "${lib.makeBinPath runtimeBins}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix LD_LIBRARY_PATH : "$out/share/sqldeveloper/modules/javafx/linux-x64/lib"

    # --- Icons ---
    mkdir -p "$out/share/icons/hicolor/32x32/apps" "$out/share/pixmaps"
    cp "$out/share/sqldeveloper/icon.png" \
       "$out/share/icons/hicolor/32x32/apps/sqldeveloper.png"
    ln -s "$out/share/icons/hicolor/32x32/apps/sqldeveloper.png" \
          "$out/share/pixmaps/sqldeveloper.png"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "sqldeveloper";
      desktopName = "Oracle SQL Developer";
      comment = "IDE for Oracle Database";
      exec = "sqldeveloper %U";
      icon = "sqldeveloper";
      terminal = false;
      categories = [
        "Development"
        "IDE"
        "Database"
      ];
      mimeTypes = [ "application/sql" ];
    })
  ];

  meta = {
    description = "IDE for Oracle Database development";
    longDescription = ''
      Oracle SQL Developer is a graphical tool that simplifies database
      development tasks. You can browse database objects, run SQL statements
      and SQL scripts, edit and debug PL/SQL statements, run reports, and
      perform data modeling.
    '';
    homepage = "https://www.oracle.com/database/sqldeveloper/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ fkomarek ];
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    mainProgram = "sqldeveloper";
  };
})
