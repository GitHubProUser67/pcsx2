#!/bin/bash

set -e

merge_binaries() {
	X86DIR=$1
	ARMDIR=$2
	echo "Merging ARM64 binaries from $ARMDIR into fat binaries at $X86DIR..."

	IFS="
"
	pushd "$X86DIR"
	for X86BIN in $(find . -type f \( -name '*.dylib' -o -name '*.a' -o -perm +111 \)); do
		if file "$X86DIR/$X86BIN" | grep "Mach-O.*x86_64" >/dev/null; then
			ARMBIN="${ARMDIR}/${X86BIN}"
			echo "Merge $ARMBIN to $X86BIN..."
			lipo -create "$X86BIN" "$ARMBIN" -o "$X86BIN"
		fi
	done
	popd
}

if [ "$#" -ne 1 ]; then
    echo "Syntax: $0 <output directory>"
    exit 1
fi

# The bundled ffmpeg has a lot of things disabled to reduce code size.
# Users may want to use system ffmpeg for additional features
: ${BUILD_FFMPEG:=1}

export MACOSX_DEPLOYMENT_TARGET=11.0

NPROCS="$(getconf _NPROCESSORS_ONLN)"
SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
INSTALLDIR="$1"
if [ "${INSTALLDIR:0:1}" != "/" ]; then
	INSTALLDIR="$PWD/$INSTALLDIR"
fi

FREETYPE=2.13.3
HARFBUZZ=11.2.0
SDL=SDL3-3.2.16
ZSTD=1.5.7
LZ4=1.10.0
LIBPNG=1.6.48
LIBJPEGTURBO=3.1.0
LIBWEBP=1.5.0
FFMPEG=6.0
MOLTENVK=1.2.9
QT=6.7.3
KDDOCKWIDGETS=2.2.3
PLUTOVG=1.1.0
PLUTOSVG=0.0.7

SHADERC=2024.1
SHADERC_GLSLANG=142052fa30f9eca191aa9dcf65359fcaed09eeec
SHADERC_SPIRVHEADERS=5e3ad389ee56fca27c9705d093ae5387ce404df4
SHADERC_SPIRVTOOLS=dd4b663e13c07fea4fbb3f70c1c91c86731099f7

mkdir -p deps-build
cd deps-build

export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export LDFLAGS="-L$INSTALLDIR/lib $LDFLAGS"
export CFLAGS="-I$INSTALLDIR/include $CFLAGS"
export CXXFLAGS="-I$INSTALLDIR/include $CXXFLAGS"
CMAKE_COMMON=(
	-DCMAKE_BUILD_TYPE=Release
	-DCMAKE_SHARED_LINKER_FLAGS="-dead_strip -dead_strip_dylibs"
	-DCMAKE_PREFIX_PATH="$INSTALLDIR"
	-DCMAKE_INSTALL_PREFIX="$INSTALLDIR"
	-DCMAKE_INSTALL_NAME_DIR='$<INSTALL_PREFIX>/lib'
)
CMAKE_ARCH_X64=-DCMAKE_OSX_ARCHITECTURES="x86_64"
CMAKE_ARCH_ARM64=-DCMAKE_OSX_ARCHITECTURES="arm64"
CMAKE_ARCH_UNIVERSAL=-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

cat > SHASUMS <<EOF
0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289  freetype-$FREETYPE.tar.xz
16c0204704f3ebeed057aba100fe7db18d71035505cb10e595ea33d346457fc8  harfbuzz-$HARFBUZZ.tar.gz
6340e58879b2d15830c8460d2f589a385c444d1faa2a4828a9626c7322562be8  $SDL.tar.gz
eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3  zstd-$ZSTD.tar.gz
537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b  lz4-$LZ4.tar.gz
46fd06ff37db1db64c0dc288d78a3f5efd23ad9ac41561193f983e20937ece03  libpng-$LIBPNG.tar.xz
7d6fab70cf844bf6769077bd5d7a74893f8ffd4dfb42861745750c63c2a5c92c  libwebp-$LIBWEBP.tar.gz
9564c72b1dfd1d6fe6274c5f95a8d989b59854575d4bbee44ade7bc17aa9bc93  libjpeg-turbo-$LIBJPEGTURBO.tar.gz
57be87c22d9b49c112b6d24bc67d42508660e6b718b3db89c44e47e289137082  ffmpeg-$FFMPEG.tar.xz
f415a09385030c6510a936155ce211f617c31506db5fbc563e804345f1ecf56e  v$MOLTENVK.tar.gz
8ccbb9ab055205ac76632c9eeddd1ed6fc66936fc56afc2ed0fd5d9e23da3097  qtbase-everywhere-src-$QT.tar.xz
9fd58144081654c3373768dd96ead294023830927b14fe3d3c1ef641fb324753  qtimageformats-everywhere-src-$QT.tar.xz
40142cb71fb1e07ad612bc361b67f5d54cd9367f9979ae6b86124a064deda06b  qtsvg-everywhere-src-$QT.tar.xz
f03bb7df619cd9ac9dba110e30b7bcab5dd88eb8bdc9cc752563b4367233203f  qttools-everywhere-src-$QT.tar.xz
dcc762acac043b9bb5e4d369b6d6f53e0ecfcf76a408fe0db5f7ef071c9d6dc8  qttranslations-everywhere-src-$QT.tar.xz
eb3b5f0c16313d34f208d90c2fa1e588a23283eed63b101edd5422be6165d528  shaderc-$SHADERC.tar.gz
aa27e4454ce631c5a17924ce0624eac736da19fc6f5a2ab15a6c58da7b36950f  shaderc-glslang-$SHADERC_GLSLANG.tar.gz
5d866ce34a4b6908e262e5ebfffc0a5e11dd411640b5f24c85a80ad44c0d4697  shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz
03ee1a2c06f3b61008478f4abe9423454e53e580b9488b47c8071547c6a9db47  shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz
b8529755b2d54205341766ae168e83177c6120660539f9afba71af6bca4b81ec  KDDockWidgets-$KDDOCKWIDGETS.tar.gz
8aa9860519c407890668c29998e8bb88896ef6a2e6d7ce5ac1e57f18d79e1525  plutovg-$PLUTOVG.tar.gz
78561b571ac224030cdc450ca2986b4de915c2ba7616004a6d71a379bffd15f3  plutosvg-$PLUTOSVG.tar.gz
EOF

curl -C - -L \
	-o "freetype-$FREETYPE.tar.xz" "https://sourceforge.net/projects/freetype/files/freetype2/$FREETYPE/freetype-$FREETYPE.tar.xz/download" \
	-o "harfbuzz-$HARFBUZZ.tar.gz" "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$HARFBUZZ.tar.gz" \
	-O "https://libsdl.org/release/$SDL.tar.gz" \
	-O "https://github.com/facebook/zstd/releases/download/v$ZSTD/zstd-$ZSTD.tar.gz" \
	-O "https://github.com/lz4/lz4/releases/download/v$LZ4/lz4-$LZ4.tar.gz" \
	-O "https://downloads.sourceforge.net/project/libpng/libpng16/$LIBPNG/libpng-$LIBPNG.tar.xz" \
	-O "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$LIBJPEGTURBO/libjpeg-turbo-$LIBJPEGTURBO.tar.gz" \
	-O "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP.tar.gz" \
	-O "https://ffmpeg.org/releases/ffmpeg-$FFMPEG.tar.xz" \
	-O "https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v$MOLTENVK.tar.gz" \
	-O "https://download.qt.io/archive/qt/${QT%.*}/$QT/submodules/qtbase-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/archive/qt/${QT%.*}/$QT/submodules/qtimageformats-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/archive/qt/${QT%.*}/$QT/submodules/qtsvg-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/archive/qt/${QT%.*}/$QT/submodules/qttools-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/archive/qt/${QT%.*}/$QT/submodules/qttranslations-everywhere-src-$QT.tar.xz" \
	-o "shaderc-$SHADERC.tar.gz" "https://github.com/google/shaderc/archive/refs/tags/v$SHADERC.tar.gz" \
	-o "shaderc-glslang-$SHADERC_GLSLANG.tar.gz" "https://github.com/KhronosGroup/glslang/archive/$SHADERC_GLSLANG.tar.gz" \
	-o "shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz" "https://github.com/KhronosGroup/SPIRV-Headers/archive/$SHADERC_SPIRVHEADERS.tar.gz" \
	-o "shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz" "https://github.com/KhronosGroup/SPIRV-Tools/archive/$SHADERC_SPIRVTOOLS.tar.gz" \
	-o "KDDockWidgets-$KDDOCKWIDGETS.tar.gz" "https://github.com/KDAB/KDDockWidgets/archive/v$KDDOCKWIDGETS.tar.gz" \
	-o "plutovg-$PLUTOVG.tar.gz" "https://github.com/sammycage/plutovg/archive/v$PLUTOVG.tar.gz" \
	-o "plutosvg-$PLUTOSVG.tar.gz" "https://github.com/sammycage/plutosvg/archive/v$PLUTOSVG.tar.gz"

shasum -a 256 --check SHASUMS

echo "Installing SDL..."
rm -fr "$SDL"
tar xf "$SDL.tar.gz"
cd "$SDL"
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSDL_X11=OFF -DBUILD_SHARED_LIBS=ON
make -C build "-j$NPROCS"
make -C build install
cd ..

if [ "$BUILD_FFMPEG" -ne 0 ]; then
	echo "Installing FFmpeg..."
	rm -fr "ffmpeg-$FFMPEG"
	tar xf "ffmpeg-$FFMPEG.tar.xz"
	cd "ffmpeg-$FFMPEG"
	mkdir build
	cd build
	LDFLAGS="-dead_strip $LDFLAGS" CFLAGS="-Os $CFLAGS" CXXFLAGS="-Os $CXXFLAGS" \
		../configure --prefix="$INSTALLDIR" \
		--enable-cross-compile --arch=x86_64 --cc='clang -arch x86_64' --cxx='clang++ -arch x86_64' --disable-x86asm \
		--disable-all --disable-autodetect --disable-static --enable-shared \
		--enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale \
		--enable-audiotoolbox --enable-videotoolbox \
		--enable-encoder=ffv1,qtrle,pcm_s16be,pcm_s16le,*_at,*_videotoolbox \
		--enable-muxer=avi,matroska,mov,mp3,mp4,wav \
		--enable-protocol=file
	make "-j$NPROCS"
	cd ..
	mkdir build-arm64
	cd build-arm64
	LDFLAGS="-dead_strip $LDFLAGS" CFLAGS="-Os $CFLAGS" CXXFLAGS="-Os $CXXFLAGS" \
		../configure --prefix="$INSTALLDIR" \
		--enable-cross-compile --arch=arm64 --cc='clang -arch arm64' --cxx='clang++ -arch arm64' --disable-x86asm \
		--disable-all --disable-autodetect --disable-static --enable-shared \
		--enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale \
		--enable-audiotoolbox --enable-videotoolbox \
		--enable-encoder=ffv1,qtrle,pcm_s16be,pcm_s16le,*_at,*_videotoolbox \
		--enable-muxer=avi,matroska,mov,mp3,mp4,wav \
		--enable-protocol=file
	make "-j$NPROCS"
	cd ..
	merge_binaries $(realpath build) $(realpath build-arm64)
	cd build
	make install
	cd ../..
fi

echo "Installing Zstd..."
rm -fr "zstd-$ZSTD"
tar xf "zstd-$ZSTD.tar.gz"
cd "zstd-$ZSTD"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_PROGRAMS=OFF -B build-dir build/cmake
make -C build-dir "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_PROGRAMS=OFF -B build-dir-arm64 build/cmake
make -C build-dir-arm64 "-j$NPROCS"
merge_binaries $(realpath build-dir) $(realpath build-dir-arm64)
make -C build-dir install
cd ..

echo "Installing LZ4..."
rm -fr "lz4-$LZ4"
tar xf "lz4-$LZ4.tar.gz"
cd "lz4-$LZ4"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DBUILD_SHARED_LIBS=ON -DLZ4_BUILD_CLI=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF -B build-dir build/cmake
make -C build-dir "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DBUILD_SHARED_LIBS=ON -DLZ4_BUILD_CLI=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF -B build-dir-arm64 build/cmake
make -C build-dir-arm64 "-j$NPROCS"
merge_binaries $(realpath build-dir) $(realpath build-dir-arm64)
make -C build-dir install
cd ..

echo "Installing libpng..."
rm -fr "libpng-$LIBPNG"
tar xf "libpng-$LIBPNG.tar.xz"
cd "libpng-$LIBPNG"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_FRAMEWORK=OFF -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_FRAMEWORK=OFF -DPNG_ARM_NEON=on -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Installing libjpegturbo..."
rm -fr "libjpeg-turbo-$LIBJPEGTURBO"
tar xf "libjpeg-turbo-$LIBJPEGTURBO.tar.gz"
cd "libjpeg-turbo-$LIBJPEGTURBO"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DENABLE_STATIC=OFF -DENABLE_SHARED=ON -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DENABLE_STATIC=OFF -DENABLE_SHARED=ON -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Installing WebP..."
rm -fr "libwebp-$LIBWEBP"
tar xf "libwebp-$LIBWEBP.tar.gz"
cd "libwebp-$LIBWEBP"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -B build \
	-DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
	-DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -B build-arm64 \
	-DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
	-DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Building FreeType without HarfBuzz..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.xz"
cd "freetype-$FREETYPE"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_BROTLI=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building HarfBuzz..."
rm -fr "harfbuzz-$HARFBUZZ"
tar xf "harfbuzz-$HARFBUZZ.tar.gz"
cd "harfbuzz-$HARFBUZZ"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DHB_BUILD_UTILS=OFF -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building FreeType with HarfBuzz..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.xz"
cd "freetype-$FREETYPE"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_BROTLI=TRUE -DFT_REQUIRE_HARFBUZZ=TRUE -B build
cmake --build build --parallel
cmake --install build
cd ..

# MoltenVK already builds universal binaries, nothing special to do here.
echo "Installing MoltenVK..."
rm -fr "MoltenVK-${MOLTENVK}"
tar xf "v$MOLTENVK.tar.gz"
cd "MoltenVK-${MOLTENVK}"
./fetchDependencies --macos
make macos
cp Package/Latest/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib "$INSTALLDIR/lib/"
cd ..

echo "Installing Qt Base..."
rm -fr "qtbase-everywhere-src-$QT"
tar xf "qtbase-everywhere-src-$QT.tar.xz"
cd "qtbase-everywhere-src-$QT"
# since we don't have a direct reference to QtSvg, it doesn't deployed directly from the main binary
# (only indirectly from iconengines), and the libqsvg.dylib imageformat plugin does not get deployed.
# We could run macdeployqt twice, but that's even more janky than patching it.
patch -u src/tools/macdeployqt/shared/shared.cpp <<EOF
--- shared.cpp
+++ shared.cpp
@@ -1119,14 +1119,8 @@
         addPlugins(QStringLiteral("networkinformation"));
     }
 
-    // All image formats (svg if QtSvg is used)
-    const bool usesSvg = deploymentInfo.containsModule("Svg", libInfix);
-    addPlugins(QStringLiteral("imageformats"), [usesSvg](const QString &lib) {
-        if (lib.contains(QStringLiteral("qsvg")) && !usesSvg)
-            return false;
-        return true;
-    });
-
+    // All image formats
+    addPlugins(QStringLiteral("imageformats"));
     addPlugins(QStringLiteral("iconengines"));
 
     // Platforminputcontext plugins if QtGui is in use
EOF
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_dbus=OFF -DFEATURE_framework=OFF -DFEATURE_icu=OFF -DFEATURE_opengl=OFF -DFEATURE_printsupport=OFF -DFEATURE_sql=OFF -DFEATURE_gssapi=OFF -DFEATURE_system_png=ON -DFEATURE_system_jpeg=ON -DFEATURE_system_zlib=ON -DFEATURE_system_freetype=ON -DFEATURE_system_harfbuzz=ON
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Installing Qt SVG..."
rm -fr "qtsvg-everywhere-src-$QT"
tar xf "qtsvg-everywhere-src-$QT.tar.xz"
cd "qtsvg-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL"
make "-j$NPROCS"
make install
cd ../..

echo "Installing Qt Image Formats..."
rm -fr "qtimageformats-everywhere-src-$QT"
tar xf "qtimageformats-everywhere-src-$QT.tar.xz"
cd "qtimageformats-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_system_webp=ON
make "-j$NPROCS"
make install
cd ../..

echo "Installing Qt Tools..."
rm -fr "qttools-everywhere-src-$QT"
tar xf "qttools-everywhere-src-$QT.tar.xz"
cd "qttools-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_assistant=OFF -DFEATURE_clang=OFF -DFEATURE_designer=OFF -DFEATURE_kmap2qmap=OFF -DFEATURE_pixeltool=OFF -DFEATURE_pkg_config=OFF -DFEATURE_qev=OFF -DFEATURE_qtattributionsscanner=OFF -DFEATURE_qtdiag=OFF -DFEATURE_qtplugininfo=OFF
make "-j$NPROCS"
make install
cd ../..

echo "Building shaderc..."
rm -fr "shaderc-$SHADERC"
tar xf "shaderc-$SHADERC.tar.gz"
cd "shaderc-$SHADERC"
cd third_party
tar xf "../../shaderc-glslang-$SHADERC_GLSLANG.tar.gz"
mv "glslang-$SHADERC_GLSLANG" "glslang"
tar xf "../../shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz"
mv "SPIRV-Headers-$SHADERC_SPIRVHEADERS" "spirv-headers"
tar xf "../../shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz"
mv "SPIRV-Tools-$SHADERC_SPIRVTOOLS" "spirv-tools"
cd ..
patch -p1 < "$SCRIPTDIR/../common/shaderc-changes.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -B build
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Installing Qt Translations..."
rm -fr "qttranslations-everywhere-src-$QT"
tar xf "qttranslations-everywhere-src-$QT.tar.xz"
cd "qttranslations-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL"
make "-j$NPROCS"
make install
cd ../..

echo "Building KDDockWidgets..."
rm -fr "KDDockWidgets-$KDDOCKWIDGETS"
tar xf "KDDockWidgets-$KDDOCKWIDGETS.tar.gz"
cd "KDDockWidgets-$KDDOCKWIDGETS"
patch -p1 < "$SCRIPTDIR/../common/kddockwidgets-dodgy-include.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DKDDockWidgets_QT6=true -DKDDockWidgets_EXAMPLES=false -DKDDockWidgets_FRONTENDS=qtwidgets -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building PlutoVG..."
rm -fr "plutovg-$PLUTOVG"
tar xf "plutovg-$PLUTOVG.tar.gz"
cd "plutovg-$PLUTOVG"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DPLUTOVG_BUILD_EXAMPLES=OFF -B build
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Building PlutoSVG..."
rm -fr "plutosvg-$PLUTOSVG"
tar xf "plutosvg-$PLUTOSVG.tar.gz"
cd "plutosvg-$PLUTOSVG"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DPLUTOSVG_ENABLE_FREETYPE=ON -DPLUTOSVG_BUILD_EXAMPLES=OFF -B build
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Cleaning up..."
cd ..
rm -rf deps-build
