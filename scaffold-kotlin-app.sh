#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[SCAFFOLD]"

# Target parameters with sensible defaults
TARGET_DIR="${1:-$HOME/workspace/u3-kotlin}"
PROJECT_NAME="${2:-MiAppModular}"
BASE_PACKAGE="${3:-com.miempresa.miapp}"

# Package path conversion: com.example.app -> com/example/app
PACKAGE_PATH="${BASE_PACKAGE//.//}"

echo "$LOG_TAG Scaffolding modular project '$PROJECT_NAME' at: $TARGET_DIR"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# ------------------------------------------------------------------------------
# 1. Root Configuration & Module Settings
# ------------------------------------------------------------------------------
echo "$LOG_TAG Generating root Gradle configuration..."

cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
kotlin.code.style=official
EOF

cat << EOF > settings.gradle.kts
rootProject.name = "$PROJECT_NAME"

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

include(":core")
include(":app")
EOF

cat << 'EOF' > build.gradle.kts
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
            freeCompilerArgs.add("-Xjsr305=strict")
        }
    }
}
EOF

# ------------------------------------------------------------------------------
# 2. Centralized Version Catalog (Gradle TOML)
# ------------------------------------------------------------------------------
echo "$LOG_TAG Generating Gradle Version Catalog (gradle/libs.versions.toml)..."
mkdir -p gradle

cat << 'EOF' > gradle/libs.versions.toml
[versions]
kotlin = "2.0.21"
coroutines = "1.9.0"
junit = "5.11.3"

[libraries]
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
junit-jupiter = { module = "org.junit.jupiter:junit-jupiter", version.ref = "junit" }

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
application = { id = "application" }
EOF

# ------------------------------------------------------------------------------
# 3. Core Module (:core) - Logic & Models
# ------------------------------------------------------------------------------
echo "$LOG_TAG Generating :core module..."
CORE_SRC="core/src/main/kotlin/$PACKAGE_PATH/core"
CORE_TEST="core/src/test/kotlin/$PACKAGE_PATH/core"
mkdir -p "$CORE_SRC" "$CORE_TEST"

cat << 'EOF' > core/build.gradle.kts
plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit.jupiter)
}

tasks.test {
    useJUnitPlatform()
}
EOF

cat << EOF > "$CORE_SRC/GreeterService.kt"
package $BASE_PACKAGE.core

class GreeterService {
    fun greet(name: String): String {
        return "Hello, \$name! Modular Kotlin system active."
    }
}
EOF

cat << EOF > "$CORE_TEST/GreeterServiceTest.kt"
package $BASE_PACKAGE.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class GreeterServiceTest {
    @Test
    fun testGreeting() {
        val service = GreeterService()
        val result = service.greet("Tester")
        assertEquals("Hello, Tester! Modular Kotlin system active.", result)
    }
}
EOF

# ------------------------------------------------------------------------------
# 4. App Module (:app) - Executable CLI Entrypoint
# ------------------------------------------------------------------------------
echo "$LOG_TAG Generating :app module..."
APP_SRC="app/src/main/kotlin/$PACKAGE_PATH"
mkdir -p "$APP_SRC"

cat << EOF > app/build.gradle.kts
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.application)
}

dependencies {
    implementation(project(":core"))
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit.jupiter)
}

application {
    mainClass.set("$BASE_PACKAGE.MainKt")
}

tasks.test {
    useJUnitPlatform()
}
EOF

cat << EOF > "$APP_SRC/Main.kt"
package $BASE_PACKAGE

import $BASE_PACKAGE.core.GreeterService
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val greeter = GreeterService()
    val message = greeter.greet("$PROJECT_NAME Runner")
    println("[APP] Output: \$message")
}
EOF

# ------------------------------------------------------------------------------
# 5. Git & Tooling Defaults
# ------------------------------------------------------------------------------
cat << 'EOF' > .gitignore
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar
.idea/
*.iml
out/
EOF

# ------------------------------------------------------------------------------
# 6. Bootstrap Gradle Wrapper via SDKMAN Gradle
# ------------------------------------------------------------------------------
echo "$LOG_TAG Bootstrapping Gradle wrapper..."
if command -v gradle >/dev/null 2>&1; then
    gradle wrapper --gradle-version 8.10.2 --distribution-type bin --no-daemon
else
    echo "$LOG_TAG Warning: System/SDKMAN 'gradle' binary not found. Wrapper could not be generated." >&2
fi

echo "$LOG_TAG Scaffolding complete for '$PROJECT_NAME'."
