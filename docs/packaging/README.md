# Packaging Overview

Reva Player has Linux packaging support for AppImage, bundled DEB, bundled RPM, and Flatpak.

Verified against repository files on 2026-05-10.

## Formats

| Format | Meaning | Current repository status | Use when |
| --- | --- | --- | --- |
| DEB | Native Debian package | Supported through bundled release script; CPack system mode is available for comparison | Debian, Ubuntu, Linux Mint, Pop!_OS, elementary OS. |
| RPM | Native RPM package | Supported through bundled `rpmbuild` script | Fedora/openSUSE/RHEL-family testing when AppImage is not preferred. |
| AppImage | Portable Linux application image | Supported through scripts | Fast cross-distro testing and distribution. |
| Flatpak | Sandboxed Linux package | Available via `dist/linux/flatpak/` manifest | Cross-distro sandboxed distribution through Flathub or local build. |

## Runtime Components To Verify

Every package must provide or depend on:

- `revaplayer` executable.
- Qt Widgets runtime and platform plugins.
- Qt SQL SQLite plugin.
- Qt DBus runtime for Linux desktop inhibition integration.
- libmpv runtime and its media stack.
- OpenGL-capable runtime environment.
- Desktop entry and icon on Linux.
- Writable application data and cache locations.

## Detailed Pages

- [DEB.md](DEB.md)
- [RPM.md](RPM.md)
- [APPIMAGE.md](APPIMAGE.md)
- [FLATPAK.md](FLATPAK.md)
- [COMPARISON.md](COMPARISON.md)
- [RECOMMENDATION.md](RECOMMENDATION.md)
- [CHECKLIST.md](CHECKLIST.md)

## Current Recommendation

Use AppImage first for broad Linux testing, DEB for Debian/Ubuntu-family users, RPM for RPM-family users after clean target-system checks, and Flatpak for sandboxed cross-distro distribution.

The v1.0.0 native package scripts bundle Qt/libmpv/media runtime files that are
stable enough to ship with the application, while graphics, audio, desktop
session, X11/Wayland, DBus, and other host-sensitive libraries are left to the
target package manager through package dependencies.

The Flatpak manifest builds libmpv, ffmpeg, and libass from source inside the
sandbox against the org.kde.Platform 6.10 runtime, so it has no host-library
dependencies beyond Flatpak itself.
