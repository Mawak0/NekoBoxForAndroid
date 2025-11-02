#!/bin/bash

# ----------------------------
# 1️⃣ Настройка окружения
# ----------------------------

# Пути к Java, Android SDK и NDK
export JAVA_HOME="C:/Program Files/AdoptOpenJDK/jdk-11.0.22"
export PATH="$JAVA_HOME/bin:$PATH"

export ANDROID_HOME="C:/Users/user/AppData/Local/Android/Sdk"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/29.0.14206865"
export NDK="$ANDROID_NDK_HOME"

# GOPATH
if [ -z "$GOPATH" ]; then
    GOPATH=$(go env GOPATH)
fi
echo "GOPATH=$GOPATH"

# ----------------------------
# 2️⃣ Подготовка папки сборки
# ----------------------------
chmod -R 777 .build 2>/dev/null || true
rm -rf .build 2>/dev/null

# ----------------------------
# 3️⃣ Установка gomobile-matsuri
# ----------------------------
if [ ! -f "$GOPATH/bin/gomobile-matsuri" ] || [ ! -f "$GOPATH/bin/gobind-matsuri" ]; then
    echo "Installing gomobile-matsuri..."

    git clone https://github.com/MatsuriDayo/gomobile.git
    pushd gomobile || exit

    # Проверяем ветку
    if git show-ref --verify --quiet refs/remotes/origin/master2; then
        git checkout origin/master2
    else
        git checkout master
    fi

    pushd cmd || exit

    # Сборка gomobile
    pushd gomobile || exit
    go install -v || exit
    popd

    pushd gobind || exit
    go install -v || exit
    popd

    popd
    popd

    rm -rf gomobile

    # mv → cp + rm
    cp "$GOPATH/bin/gomobile" "$GOPATH/bin/gomobile-matsuri"
    cp "$GOPATH/bin/gobind" "$GOPATH/bin/gobind-matsuri"
    rm "$GOPATH/bin/gomobile"
    rm "$GOPATH/bin/gobind"
fi

# ----------------------------
# 4️⃣ Инициализация gomobile
# ----------------------------
GOBIND=gobind-matsuri "$GOPATH/bin/gomobile-matsuri" init

# ----------------------------
# 5️⃣ Сборка libcore.aar
# ----------------------------

# Копируем go.mod в каждую временную сборочную директорию
BUILD=".build"
for arch in android-arm android-arm64 android-386 android-amd64; do
    mkdir -p "$BUILD/src-$arch"
    cp "./go.mod" "$BUILD/src-$arch/go.mod"
done

"$GOPATH/bin/gomobile-matsuri" bind -v \
    -androidapi 21 \
    -cache "$(realpath $BUILD)" \
    -trimpath \
    -ldflags='-s -w' \
    -tags='with_conntrack,with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api' \
    . || exit 1

# Копируем libcore.aar в app/libs
proj="../app/libs"
mkdir -p "$proj"
cp -f libcore.aar "$proj"

echo "✅ libcore.aar installed to $(realpath $proj)/libcore.aar"
