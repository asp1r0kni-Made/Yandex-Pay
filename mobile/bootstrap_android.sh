#!/usr/bin/env bash
# Запустите один раз перед локальной разработкой/сборкой:
#   cd mobile && ./bootstrap_android.sh
#
# Скрипт генерирует стандартную Android-папку (gradle wrapper и т.д.)
# и накладывает поверх неё наши кастомные файлы из android_overlay/.
set -e

echo "Генерируем Android-каркас через flutter create..."
flutter create --platforms=android --org com.splitbank .

echo "Накладываем кастомные файлы (AndroidManifest, FileProvider)..."
cp -rf android_overlay/* android/

echo "Поднимаем minSdkVersion до 23 (нужно для local_auth / secure storage)..."
sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' android/app/build.gradle && rm -f android/app/build.gradle.bak

echo "Устанавливаем зависимости..."
flutter pub get

echo "Генерируем иконку приложения..."
flutter pub run flutter_launcher_icons

echo "Готово! Теперь можно собирать: flutter build apk --release"
