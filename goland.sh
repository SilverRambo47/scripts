#!/bin/sh
# Copyright 2000-2022 JetBrains s.r.o. and contributors. Use of this source code is governed by the Apache 2.0 license.

# ---------------------------------------------------------------------
# GoLand startup script.
# ---------------------------------------------------------------------

message()
{
  TITLE="Cannot start GoLand"
  if [ -n "$(command -v zenity)" ]; then
    zenity --error --title="$TITLE" --text="$1" --no-wrap
  elif [ -n "$(command -v kdialog)" ]; then
    kdialog --error "$1" --title "$TITLE"
  elif [ -n "$(command -v notify-send)" ]; then
    notify-send "ERROR: $TITLE" "$1"
  elif [ -n "$(command -v xmessage)" ]; then
    xmessage -center "ERROR: $TITLE: $1"
  else
    printf "ERROR: %s\n%s\n" "$TITLE" "$1"
  fi
}

if [ -z "$(command -v uname)" ] || [ -z "$(command -v realpath)" ] || [ -z "$(command -v dirname)" ] || [ -z "$(command -v cat)" ] || \
   [ -z "$(command -v grep)" ]; then
  TOOLS_MSG="Required tools are missing:"
  for tool in uname realpath grep dirname cat ; do
     test -z "$(command -v $tool)" && TOOLS_MSG="$TOOLS_MSG $tool"
  done
  message "$TOOLS_MSG (SHELL=$SHELL PATH=$PATH)"
  exit 1
fi

# shellcheck disable=SC2034
GREP_OPTIONS=''
OS_TYPE=$(uname -s)
OS_ARCH=$(uname -m)

# ---------------------------------------------------------------------
# Ensure $IDE_HOME points to the directory where the IDE is installed.
# ---------------------------------------------------------------------
IDE_BIN_HOME=$(dirname "$(realpath "$0")")
IDE_HOME=$(dirname "${IDE_BIN_HOME}")
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# ---------------------------------------------------------------------
# Locate a JRE installation directory command -v will be used to run the IDE.
# Try (in order): $GOLAND_JDK, .../goland.jdk, .../jbr, $JDK_HOME, $JAVA_HOME, "java" in $PATH.
# ---------------------------------------------------------------------
JRE=""

# shellcheck disable=SC2154
if [ -n "$GOLAND_JDK" ] && [ -x "$GOLAND_JDK/bin/java" ]; then
  JRE="$GOLAND_JDK"
fi

if [ -z "$JRE" ] && [ -s "${CONFIG_HOME}/JetBrains/GoLand2022.2/goland.jdk" ]; then
  USER_JRE=$(cat "${CONFIG_HOME}/JetBrains/GoLand2022.2/goland.jdk")
  if [ -x "$USER_JRE/bin/java" ]; then
    JRE="$USER_JRE"
  fi
fi

if [ -z "$JRE" ] && [ "$OS_TYPE" = "Linux" ] && [ -f "$IDE_HOME/jbr/release" ]; then
  JBR_ARCH="OS_ARCH=\"$OS_ARCH\""
  if grep -q -e "$JBR_ARCH" "$IDE_HOME/jbr/release" ; then
    JRE="$IDE_HOME/jbr"
  fi
fi

# shellcheck disable=SC2153
if [ -z "$JRE" ]; then
  if [ -n "$JDK_HOME" ] && [ -x "$JDK_HOME/bin/java" ]; then
    JRE="$JDK_HOME"
  elif [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JRE="$JAVA_HOME"
  fi
fi

if [ -z "$JRE" ]; then
  JAVA_BIN=$(command -v java)
else
  JAVA_BIN="$JRE/bin/java"
fi

if [ -z "$JAVA_BIN" ] || [ ! -x "$JAVA_BIN" ]; then
  message "No JRE found. Please make sure \$GOLAND_JDK, \$JDK_HOME, or \$JAVA_HOME point to valid JRE installation."
  exit 1
fi

# ---------------------------------------------------------------------
# Collect JVM options and IDE properties.
# ---------------------------------------------------------------------
IDE_PROPERTIES_PROPERTY=""
# shellcheck disable=SC2154
if [ -n "$GOLAND_PROPERTIES" ]; then
  IDE_PROPERTIES_PROPERTY="-Didea.properties.file=$GOLAND_PROPERTIES"
fi

VM_OPTIONS_FILE=""
USER_VM_OPTIONS_FILE=""
# shellcheck disable=SC2154
if [ -n "$GOLAND_VM_OPTIONS" ] && [ -r "$GOLAND_VM_OPTIONS" ]; then
  # 1. $<IDE_NAME>_VM_OPTIONS
  VM_OPTIONS_FILE="$GOLAND_VM_OPTIONS"
else
  # 2. <IDE_HOME>/bin/[<os>/]<bin_name>.vmoptions ...
  if [ -r "${IDE_BIN_HOME}/goland64.vmoptions" ]; then
    VM_OPTIONS_FILE="${IDE_BIN_HOME}/goland64.vmoptions"
  else
    test "${OS_TYPE}" = "Darwin" && OS_SPECIFIC="mac" || OS_SPECIFIC="linux"
    if [ -r "${IDE_BIN_HOME}/${OS_SPECIFIC}/goland64.vmoptions" ]; then
      VM_OPTIONS_FILE="${IDE_BIN_HOME}/${OS_SPECIFIC}/goland64.vmoptions"
    fi
  fi
  # ... [+ <IDE_HOME>.vmoptions (Toolbox) || <config_directory>/<bin_name>.vmoptions]
  if [ -r "${IDE_HOME}.vmoptions" ]; then
    USER_VM_OPTIONS_FILE="${IDE_HOME}.vmoptions"
  elif [ -r "${CONFIG_HOME}/JetBrains/GoLand2022.2/goland64.vmoptions" ]; then
    USER_VM_OPTIONS_FILE="${CONFIG_HOME}/JetBrains/GoLand2022.2/goland64.vmoptions"
  fi
fi

VM_OPTIONS=""
USER_GC=""
if [ -n "$USER_VM_OPTIONS_FILE" ]; then
  grep -E -q -e "-XX:\+.*GC" "$USER_VM_OPTIONS_FILE" && USER_GC="yes"
fi
if [ -n "$VM_OPTIONS_FILE" ] || [ -n "$USER_VM_OPTIONS_FILE" ]; then
  if [ -z "$USER_GC" ] || [ -z "$VM_OPTIONS_FILE" ]; then
    VM_OPTIONS=$(cat "$VM_OPTIONS_FILE" "$USER_VM_OPTIONS_FILE" 2> /dev/null | grep -E -v -e "^#.*")
  else
    VM_OPTIONS=$({ grep -E -v -e "-XX:\+Use.*GC" "$VM_OPTIONS_FILE"; cat "$USER_VM_OPTIONS_FILE"; } 2> /dev/null | grep -E -v -e "^#.*")
  fi
else
  message "Cannot find a VM options file"
fi

CLASS_PATH="$IDE_HOME/lib/util.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/app.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/3rd-party-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jna.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/platform-statistics-devkit.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jps-model.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-core.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-framework.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/stats.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/protobuf.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/external-system-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/forms_rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/intellij-test-discovery.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-swing.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/groovy.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/annotations-java5.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-9.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-analysis-9.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-commons-9.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-tree-9.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-util-9.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/async-profiler.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/byte-buddy-agent.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/error-prone-annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/externalProcess-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/grpc-netty-shaded.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/intellij-coverage-agent-1.0.673.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jetbrains-annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jffi-1.3.9-native.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jffi-1.3.9.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-a64asm-1.0.0.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-ffi-2.2.12.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-x86asm-1.0.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jsch-agent.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/junixsocket-core.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/lz4-java.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/platform-objectSerializer-annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/pty4j.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-text.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/util_rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/winp.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/dbus-java-3.2.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/java-utils-1.0.6.jar"

# ---------------------------------------------------------------------
# Run the IDE.
# ---------------------------------------------------------------------
IFS="$(printf '\n\t')"
# shellcheck disable=SC2086
exec "$JAVA_BIN" \
  -classpath "$CLASS_PATH" \
  ${VM_OPTIONS} \
  "-XX:ErrorFile=$HOME/java_error_in_goland_%p.log" \
  "-XX:HeapDumpPath=$HOME/java_error_in_goland_.hprof" \
  "-Djb.vmOptionsFile=${USER_VM_OPTIONS_FILE:-${VM_OPTIONS_FILE}}" \
  ${IDE_PROPERTIES_PROPERTY} \
  -Djava.system.class.loader=com.intellij.util.lang.PathClassLoader -Didea.strict.classpath=true -Didea.vendor.name=JetBrains -Didea.paths.selector=GoLand2022.2 -Didea.platform.prefix=GoLand -Dsplash=true --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.nio.charset=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/jdk.internal.vm=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.security.ssl=ALL-UNNAMED --add-opens=java.base/sun.security.util=ALL-UNNAMED --add-opens=java.desktop/com.sun.java.swing.plaf.gtk=ALL-UNNAMED --add-opens=java.desktop/java.awt=ALL-UNNAMED --add-opens=java.desktop/java.awt.dnd.peer=ALL-UNNAMED --add-opens=java.desktop/java.awt.event=ALL-UNNAMED --add-opens=java.desktop/java.awt.image=ALL-UNNAMED --add-opens=java.desktop/java.awt.peer=ALL-UNNAMED --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.desktop/javax.swing.plaf.basic=ALL-UNNAMED --add-opens=java.desktop/javax.swing.text.html=ALL-UNNAMED --add-opens=java.desktop/sun.awt.X11=ALL-UNNAMED --add-opens=java.desktop/sun.awt.datatransfer=ALL-UNNAMED --add-opens=java.desktop/sun.awt.image=ALL-UNNAMED --add-opens=java.desktop/sun.awt=ALL-UNNAMED --add-opens=java.desktop/sun.font=ALL-UNNAMED --add-opens=java.desktop/sun.java2d=ALL-UNNAMED --add-opens=java.desktop/sun.swing=ALL-UNNAMED --add-opens=jdk.attach/sun.tools.attach=ALL-UNNAMED --add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED --add-opens=jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED \
  com.intellij.idea.Main \
  "$@"
