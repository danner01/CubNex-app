# Configuración Android & iOS — Plantilla para nuevo proyecto Flutter

> Copia estas configuraciones exactas para garantizar compatibilidad sin instalar versiones adicionales de Gradle, JDK, NDK ni CocoaPods.

---

## Versiones clave del entorno

| Herramienta | Versión |
|---|---|
| Flutter SDK | `D:\flutter` (o donde esté instalado) |
| Android SDK | `D:\Sdk` |
| Kotlin | `2.1.0` |
| AGP (Android Gradle Plugin) | `8.12.2` |
| NDK | `27.3.13750724` |
| compileSdk / targetSdk | `36` |
| Java / JVM target | `11` (JavaVersion.VERSION_11) |
| Firebase BoM | `34.1.0` |
| Dart SDK | `^3.6.2` |

---

## Android

### `android/settings.gradle.kts`

```kotlin
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io") {
            content {
                includeGroup("io.flutter")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.2" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.3") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
```

---

### `android/build.gradle.kts`

```kotlin
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
```

---

### `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
kotlin.incremental=false

# Estabilidad en Windows cuando proyecto y caché están en discos distintos
kotlin.compiler.execution.strategy=in-process
org.gradle.workers.max=2

# Ajusta la ruta si C: tiene poco espacio (crear la carpeta antes)
java.io.tmpdir=D:/gradle_tmp
```

---

### `android/app/build.gradle.kts`

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tuempresa.tuapp"   // <-- Cambiar
    compileSdk = 36
    ndkVersion = "27.3.13750724"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tuempresa.tuapp"   // <-- Cambiar
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("com.google.android.material:material:1.12.0")
    // Firebase BoM — sin versiones individuales en cada lib
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))
    implementation("com.google.firebase:firebase-auth")
}
```

---

### `android/local.properties`

> **No commitear** — archivo local de cada máquina.

```properties
sdk.dir=D:\Sdk
flutter.sdk=D:\flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

---

### `android/key.properties`

> **No commitear** — contiene credenciales del keystore.

```properties
keyAlias=TU_KEY_ALIAS
keyPassword=TU_KEY_PASSWORD
storeFile=../keys/tu_keystore.jks
storePassword=TU_STORE_PASSWORD
```

Genera el keystore con:
```bash
keytool -genkey -v -keystore tu_keystore.jks -alias TU_KEY_ALIAS \
  -keyalg RSA -keysize 2048 -validity 10000
```

---

### `android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.x-bin.zip
```

> Usa la misma versión de wrapper que genera el AGP `8.12.2`. Puedes verificarla con `./gradlew --version` en el proyecto original.

---

## iOS

### `ios/Podfile`

```ruby
# platform :ios, '13.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. Run flutter pub get first."
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found. Try deleting Generated.xcconfig and run flutter pub get."
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end

# Solo si usas Firebase Messaging con extensión de notificaciones:
target 'ImageNotification' do
  use_frameworks!
  pod 'Firebase/Messaging'
end
```

---

## `pubspec.yaml` — Dependencias base probadas

```yaml
environment:
  sdk: ^3.6.2

dependencies:
  flutter:
    sdk: flutter
  # State management
  bloc: ^9.0.0
  flutter_bloc: ^9.0.0
  equatable: ^2.0.7
  # Firebase
  firebase_core: ^3.12.1
  firebase_auth: ^5.5.1
  firebase_messaging: ^15.2.10
  google_sign_in: ^6.0.0
  # UI / UX
  cupertino_icons: ^1.0.8
  flutter_animate: ^4.5.2
  flutter_svg: ^2.0.17
  font_awesome_flutter: ^10.8.0
  cached_network_image: ^3.4.1
  # Navegación
  go_router: ^14.8.0
  # Red
  http: ^1.3.0
  connectivity_plus: ^6.1.3
  # Almacenamiento local
  shared_preferences: ^2.5.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  # Permisos y sistema
  permission_handler: ^12.0.0
  package_info_plus: ^8.2.1
  url_launcher: ^6.3.1
  # Localización
  flutter_localizations:
    sdk: flutter
  easy_localization: ^3.0.7
  intl: ^0.20.2
  # Notificaciones locales
  flutter_local_notifications: ^19.5.0
  # Formularios
  formz: ^0.8.0
  # Logging
  logger: ^2.5.0
  # Inyección de dependencias
  get_it: ^8.0.3
  # Compartir
  share_plus: ^10.1.4
  # Pagos (opcional)
  flutter_stripe: ^11.0.0
  # Imágenes
  image: ^4.0.17
  image_picker: ^1.1.2
  sign_in_with_apple: ^6.1.1
  # Mapas (opcional)
  google_maps_flutter: ^2.12.1
  geocoding: ^3.0.0
  geolocator: ^13.0.4
  # Cámara / Scanner (opcional)
  camera: ^0.11.3
  camera_android: ^0.10.10+6
  mobile_scanner: ^7.1.3
  google_mlkit_text_recognition: ^0.15.0
  # Otros
  audioplayers: ^6.1.0
  either_dart: ^1.0.0
  intl_phone_field: ^3.2.0
  marquee: ^2.2.3
  pinput: ^5.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  change_app_package_name: ^1.5.0
  icons_launcher: ^3.0.1
```

---

## Checklist para nuevo proyecto

- [ ] Crear proyecto: `flutter create --org com.tuempresa tuapp`
- [ ] Reemplazar `android/settings.gradle.kts` con el de arriba
- [ ] Reemplazar `android/build.gradle.kts` con el de arriba
- [ ] Reemplazar `android/gradle.properties` con el de arriba
- [ ] Reemplazar `android/app/build.gradle.kts` con el de arriba — cambiar `namespace` y `applicationId`
- [ ] Crear `android/local.properties` apuntando a tus rutas locales
- [ ] Crear `android/key.properties` con tu keystore (si vas a release)
- [ ] Actualizar `pubspec.yaml` con las dependencias necesarias
- [ ] Reemplazar `ios/Podfile` con el de arriba
- [ ] Agregar `google-services.json` en `android/app/` (Firebase)
- [ ] Agregar `GoogleService-Info.plist` en `ios/Runner/` (Firebase)
- [ ] Ejecutar `flutter pub get` y luego `cd ios && pod install`
- [ ] Crear carpeta `D:/gradle_tmp` si usas esa ruta en `gradle.properties`
- [ ] Cambiar package name: `dart run change_app_package_name:main com.tuempresa.tuapp`
