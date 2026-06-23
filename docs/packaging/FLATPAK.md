# Flatpak Packaging

Flatpak is the sandboxed Linux package format for Reva Player. It bundles the
application with its own runtime (org.kde.Platform 6.x, which provides Qt 6)
and builds libmpv, ffmpeg, and libass from source inside the sandbox, so the
same package runs across distributions without host-library dependencies.

Verified against repository files and a local flatpak-builder build on
2026-06-21.

## Target Systems

Any Linux distribution with Flatpak support installed:

- Fedora, openSUSE, Arch/Manjaro (Flatpak pre-installed or easily available)
- Ubuntu, Debian, Linux Mint, Pop!_OS (install `flatpak` and add Flathub)
- elementary OS, KDE neon, EndeavourOS, etc.

## Package Goals

- Install `revaplayer` into the Flatpak sandbox (`/app/bin/revaplayer`).
- Register desktop launcher and icon via CMake install rules.
- Register AppStream metadata.
- Provide Qt 6, libmpv, ffmpeg, and libass inside the sandbox.
- Read local media files via `--filesystem=host:ro`.
- Preserve user data across upgrades in `~/.var/app/io.github.moayad30.revaplayer/`.

## Runtime And Dependencies

| Component | Source | Notes |
| --- | --- | --- |
| Qt 6 (Widgets, Sql, DBus, OpenGLWidgets) | org.kde.Platform/SDK 6.10 | Provided by the runtime. Qt SQLite driver included. |
| libmpv 0.41.0 | Built from source in manifest | `meson -Dlibmpv=true -Dalsa=disabled -Dlua=disabled`. |
| ffmpeg 8.1.2 | Built from source in manifest | Player-focused: shared, GPL, gnutls, png encoder only. |
| libass 0.17.4 | Built from source in manifest | Subtitle rendering. harfbuzz/fontconfig from SDK. |
| SQLite | Qt SQL SQLite driver | Provided by the KDE runtime. |

The KDE runtime does NOT ship libmpv or ffmpeg, so they are built as nested
modules in the manifest. The `shared-modules` repository is no longer needed
because it stopped shipping libmpv/ffmpeg; the manifest builds them inline.

## Sandbox Permissions

| Permission | Why |
| --- | --- |
| `--share=ipc` | X11 shared memory / Qt IPC. |
| `--socket=fallback-x11` | X11 rendering fallback. |
| `--socket=wayland` | Native Wayland rendering. |
| `--device=all` | GPU/render nodes (`/dev/dri`) for OpenGL + VA-API. |
| `--socket=pulseaudio` | Audio output (PipeWire-Pulse compatibility). |
| `--filesystem=host:ro` | Read local media libraries anywhere on the host. |
| `--filesystem=xdg-pictures` | Write screenshots to `~/Pictures`. |

User data (SQLite database, thumbnails, settings, window state) is written to
sandboxed XDG locations under `~/.var/app/io.github.moayad30.revaplayer/`
automatically.

## Build Prerequisites

Install `flatpak` and `flatpak-builder`, and ensure the Flathub remote is
configured:

```bash
# Debian/Ubuntu
sudo apt install flatpak flatpak-builder

# Fedora
sudo dnf install flatpak flatpak-builder

# Arch
sudo pacman -S flatpak flatpak-builder

# Add Flathub remote (if not already present)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

The build script will automatically install `org.kde.Platform//6.10` and
`org.kde.Sdk//6.10` from Flathub if they are not already present.

## Local Build Steps

```bash
# From the repository root:
dist/linux/flatpak/build-flatpak.sh
```

This runs `flatpak-builder` with the manifest, exports the result into a local
OSTree repo (`dist/flatpak/repo`), adds a local remote, and installs the app
for the current user.

Options:

```bash
# Build without installing
dist/linux/flatpak/build-flatpak.sh --no-install

# Custom build/repo directories
dist/linux/flatpak/build-flatpak.sh --build-dir /tmp/rv-build --repo-dir /tmp/rv-repo
```

After installation, run the app:

```bash
flatpak run io.github.moayad30.revaplayer
```

## Manual Build (Without The Script)

```bash
cd dist/linux/flatpak

flatpak-builder \
    --force-clean \
    --repo ../../../dist/flatpak/repo \
    --state-dir ../../../build-flatpak-state \
    ../../../build-flatpak \
    io.github.moayad30.revaplayer.yaml

# Install from the local repo
flatpak remote-add --user --if-not-exists --no-gpg-verify local-revaplayer ../../../dist/flatpak/repo
flatpak install --user local-revaplayer io.github.moayad30.revaplayer
```

## Publishing To Flathub

1. Fork the [flathub/flathub](https://github.com/flathub/flathub) repository.
2. Create a new directory named `io.github.moayad30.revaplayer` in your fork.
3. Copy the manifest into it and change the `type: dir` source to a
   `type: git` source pointing at the RevaPlayer repository with the correct
   commit/tag:

   ```yaml
   sources:
     - type: git
       url: https://github.com/Moayad30/Reva_Player.git
       tag: v1.0.0   # or a specific commit
   ```

4. Submit a pull request to flathub/flathub.
5. Flathub CI will build and test the manifest. Once merged, the app appears on
   Flathub and users can install it with:

   ```bash
   flatpak install flathub io.github.moayad30.revaplayer
   ```

See the [Flathub submission guide](https://docs.flathub.org/docs/for-app-authors/submission/)
for the full process.

## Thumbnail Note

Reva Player ships `resources/mpv/thumbfast.lua` for on-hover thumbnail
generation. The Flatpak manifest builds libmpv with `lua=disabled` and drops
the `mpv` cplayer binary, so hover thumbnails are **disabled** in the Flatpak
build. Playback and subtitles are fully functional.

To enable thumbnails later:

1. Add the `shared-modules` git submodule:
   `https://github.com/flathub/shared-modules.git`
2. Add `- shared-modules/lua5.1/lua-5.1.5.json` as the first entry under
   libmpv's `modules:`.
3. Change libmpv's `-Dlua=disabled` to `-Dlua=enabled`.
4. Remove the `/bin/mpv` cleanup entry so thumbfast can spawn the bundled mpv.

## Uninstall And Upgrade

```bash
# Uninstall
flatpak uninstall io.github.moayad30.revaplayer

# User data remains under ~/.var/app/io.github.moayad30.revaplayer/
# For full cleanup:
rm -rf ~/.var/app/io.github.moayad30.revaplayer
```

Upgrades preserve `revaplayer.sqlite` and all user data in the sandboxed XDG
directory.

## Common Issues

- **Runtime download is large** — org.kde.Platform/SDK 6.10 is ~1.5 GB. The
  build script installs it automatically on first run.
- **Build takes 20–40 minutes** — ffmpeg, libass, and libmpv are compiled from
  source. Subsequent builds use the flatpak-builder cache and are faster.
- **No hover thumbnails** — see the Thumbnail Note above.
- **https stream playback** — requires gnutls in the SDK. If gnutls is
  unavailable, drop `--enable-gnutls` from the ffmpeg config-opts (local
  playback is unaffected).

## Evaluation

| Factor | Rating | Notes |
| --- | --- | --- |
| Performance | High | Native rendering; minimal sandbox overhead. |
| Installation ease | High | One command for users once on Flathub. |
| Update ease | High | Flatpak handles updates automatically. |
| Maintenance | Medium | Manifest must track runtime/libmpv/ffmpeg versions. |
| Compatibility | High | Runs on any distro with Flatpak. |
| Build difficulty | Medium | Straightforward but slow (3 source builds). |
| Distribution reach | High | All Linux distributions via Flathub. |

Ratings are estimates, not benchmarks.

## When Flatpak Is Best

- You want one package that runs on every Linux distribution.
- You want sandboxed, app-store-style distribution with automatic updates.
- Users are on distributions where AppImage/DEB/RPM are inconvenient.

## When Flatpak Is Not Best

- You need hover thumbnails (disabled in this build — see Thumbnail Note).
- You need to write to arbitrary host paths (sandbox limits writes).
- Target systems do not have Flatpak installed and cannot install it.
