#!/bin/bash
# build.sh - Android 6.12 kernel build script for OnePlus 15
# Adapted from Sakura.MTX-OP9-Pro/build.sh by Madara273
# Semi-automatic script suitable for use in Ubuntu, Debian, Kali and NetHunter
# Author Madara273
# ----------------------------------------------------------------------------

# ---- Define colors (real ESC via $'...') ----
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
PURPLE=$'\033[0;35m'
MAGENTA=$'\033[1;35m'
LGREEN=$'\033[92m'
PINK=$'\033[38;5;206m'
CYAN=$'\033[0;36m'
BLUE=$'\033[0;34m'
GREY=$'\033[38;5;250m'   # light grey (256-color)
NC=$'\033[0m'            # reset

# ---- Get the absolute path of the current directory ----
KERNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KERNEL_DIR" || exit 1
CURRENT_DIR="$KERNEL_DIR"
# Resolve build and toolchain paths from the current user's home, regardless
# of where the kernel checkout is located.
HOST_ROOT="$(cd -- "${HOME:?HOME must be set}" && pwd)" || exit 1
BUILD_ROOT="${OP15R_BUILD_ROOT:-$HOST_ROOT/Nezuko}"
LOCAL_TOOLCHAIN="$HOST_ROOT/Madara-Built/SAKURA"

# ---- Set Eastern Time timezone ----
export TZ=Europe/Kiev # Enter your time zone

# ---- random_color - generates a random color for output to the terminal ----
random_color() {
	local colors=($GREEN $RED $YELLOW $PURPLE $BLUE)	# Array of colors
	local random_index=$((RANDOM % ${#colors[@]}))		# Random index
	echo -e "${colors[$random_index]}"			# For color interpretation
}

# ---- Get information about the distribution and its version ----
. /etc/os-release 2>/dev/null || { OS=$(uname -s); VERSION_ID=$(uname -r); }

# ---- Output information to the terminal -----
echo -e "\n$(random_color)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "    - OS: $NAME $VERSION_ID"
echo -e "    - Kernel: $(uname -r)"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ----  ASCII Art Logo with random colors ----
ascii_art_logo() {
	echo -e "
$(random_color)********************************NEZUKO********************************${NC}
$(random_color) ______ ______ _______ _______ _______ _______ ___ ___ ______ _______ ${NC}
$(random_color)|   __ \   __ \       |_     _|       |_     _|   |   |   __ \    ___|${NC}
$(random_color)|    __/      <   -   | |   | |   -   | |   |  \     /|    __/    ___|${NC}
$(random_color)|___|  |___|__|_______| |___| |_______| |___|   |___| |___|  |_______|${NC}
"
}

# ---- Prompt user for input ----
echo -e "${PURPLE}Enter KBUILD_USER:${NC}"
read -t 5 -rp "KBUILD_USER: " KBUILD_USER
KBUILD_USER="${KBUILD_USER:-Madara273}"	# If user doesn't enter a value, use "Madara273"
echo "$KBUILD_USER"	# Output the value of KBUILD_USER

echo -e "${PURPLE}Enter KBUILD_HOST:${NC}"
read -t 5 -rp "KBUILD_HOST: " KBUILD_HOST
KBUILD_HOST="${KBUILD_HOST:-Kali_GNU/Linux-2026.2}"	# If user doesn't enter a value, use "Kali_GNU/Linux-2026.2"
echo "$KBUILD_HOST"	# Output the value of KBUILD_HOST

# ---- Set environment variables and Target Variables ----
THREAD="${1:-$(nproc --all)}"
TARGET_ARCH="arm64"
TARGET_SUBARCH="arm64"
TARGET_BUILD_USER="$KBUILD_USER"
TARGET_BUILD_HOST="$KBUILD_HOST"
TARGET_DEVICE="OP612DL1"
TARGET_PRODUCT="$TARGET_DEVICE"
BUILD_TIMESTAMP="${OP15R_BUILD_TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"
TARGET_OUT="$BUILD_ROOT/out"
TARGET_CC="clang"
TARGET_HOSTLD="ld.lld"
SYSTEM_PATH="$PATH"
export ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
export KBUILD_BUILD_USER="$TARGET_BUILD_USER" KBUILD_BUILD_HOST="$TARGET_BUILD_HOST"
export KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP:-$(date -u)}"
export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct 2>/dev/null || date +%s)"
PATH_MAP="-fdebug-prefix-map=$HOST_ROOT=. -fmacro-prefix-map=$HOST_ROOT=. -ffile-prefix-map=$HOST_ROOT=."
export KCFLAGS="$PATH_MAP -no-canonical-prefixes -fdiagnostics-color=never -Qunused-arguments -Wno-unused-command-line-argument -D__ANDROID_COMMON_KERNEL__ -Wno-error -pipe -mcpu=oryon-1 -O2"
export KCPPFLAGS="$PATH_MAP -DCONFIG_OPTIMIZE_INLINING"
export HOSTCFLAGS="${HOSTCFLAGS:-} -Wno-error=incompatible-pointer-types-discards-qualifiers"
export KBUILD_GENDWARFKSYMS_STABLE=1

# ---- Kernel target parameters ----
TARGET_KERNEL_FILE="$TARGET_OUT/arch/arm64/boot/Image"
TARGET_KERNEL_NAME="Nezuko"
get_kernel_version(){
	TARGET_KERNEL_MOD_VERSION="$(make kernelversion O="$TARGET_OUT" ARCH=arm64)"
}

# ---- Final kernel build parameters ----
FINAL_KERNEL_BUILD_PARA="ARCH=$TARGET_ARCH \
			 SUBARCH=$TARGET_SUBARCH \
			 HOSTLD=$TARGET_HOSTLD \
			 CC=$TARGET_CC \
			 HOSTCC=clang \
			 LD=ld.lld \
			 LLVM=1 \
			 LLVM_IAS=1 \
			 O=$TARGET_OUT \
			 TARGET_PRODUCT=$TARGET_DEVICE \
			 KBUILD_BUILD_USER=$TARGET_BUILD_USER \
			 KBUILD_BUILD_HOST=$TARGET_BUILD_HOST \
			 -j$THREAD"

# ----  Defconfig parameters ----
DEFCONFIG_PATH=arch/arm64/configs
DEFCONFIG_NAME="gki_defconfig"

# ---- Time parameters ----
START_SEC=$(date +%s)
CURRENT_TIME="$BUILD_TIMESTAMP"

# ---- Setup secure keystore paths ----
SIGNER_DIR="$BUILD_ROOT/.sakura"

KEYSTORE="$SIGNER_DIR/keystore.p12"
PASSFILE="$SIGNER_DIR/.store_pass"
ALIASFILE="$SIGNER_DIR/.alias"
ROOTCA_KEY="$SIGNER_DIR/rootCA.key"
ROOTCA_CERT="$SIGNER_DIR/rootCA.pem"
TENZO_KEY="$SIGNER_DIR/tenzo.key"
TENZO_CERT="$SIGNER_DIR/tenzo.crt"
P12_FILE="$SIGNER_DIR/tenzo.p12"
CSR_FILE="$SIGNER_DIR/tenzo.csr"

# ---- Logging / Output ----
AK3_PATH="$TARGET_OUT/AnyKernel3"
LOG_FILE="$AK3_PATH/build.log"
WARNING_PATTERN="warning"
ERROR_PATTERN="error"
NORMAL_PATTERN="normal"

# ---- Getting information about git remote, branch and commit ----
remote=$(git remote -v 2>&1 | grep push | head -n1 | cut -f2 | sed "s/(push)//" | cut -f4 -d "/")
domain=$(git remote -v 2>&1 | grep push | head -n1 | cut -f2 | sed "s/(push)//" | cut -f5 -d "/" | xargs)
branch=$(git status 2>&1 | grep "On branch" | sed -e 's/On branch //g')
commit=$(git rev-parse --short=8 HEAD)

# ----  Kernel DIR ----
KERNEL_DIR=$(pwd)
echo -e "${GREEN}$KERNEL_DIR${NC}"

# ---- Function to display build information ----
display_build_info(){
echo -e "${PURPLE}***************Nezuko-Kernel**************${NC}"
	echo -e "PRODUCT: $TARGET_DEVICE"
	echo -e "USER: $KBUILD_USER"
	echo -e "HOST: $KBUILD_HOST"
	echo -e "SUBLEVEL: $(grep -E '^SUBLEVEL =' Makefile | awk '{print $3}')"
	echo -e "${PURPLE}***************Device-Builder**************${NC}"
	echo -e "BUILD_DEVICE: $(lsb_release -a 2>/dev/null | grep Description | cut -d: -f2 | xargs)"
	echo -e "Compiler: $($TARGET_CC --version | head -n 1)"
	echo -e "Core count: $(nproc)"
	echo -e "Build Date: $(date +"%Y-%m-%d %H:%M")"
	echo -e "${PURPLE}*************last commit details***********${NC}"
	echo -e "Last commit (name): $(git log -1 --pretty=format:%s)"
	echo -e "Last commit (hash): $(git log -1 --pretty=format:%H)"
	echo -e "${PURPLE}*******************************************${NC}"
}

# ---- Function for interactive action selection with timeout ----
choose_action(){
	while true; do
		echo -e "Choose an action:"
		echo -e "${GREEN}1.👉 Install necessary packages${NC}"
		echo -e "${GREEN}2.👉 Start kernel compilation${NC}"
		echo -e "${GREEN}3.👉 Exit program${NC}"

		# Set timeout for user input (5 seconds)
		read -t 5 -p "Enter the action number (1/2/3): " choice

		# Default to compilation; installing system packages remains explicit.
		[ -z "$choice" ] && echo -e "${YELLOW}No input detected. Automatically selecting action 2.${NC}" && choice=2

		case $choice in
			1 ) install_packages;;
			2 ) compile_kernel && break || return 1;;
			3 ) exit;;
			* ) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}";;
		esac
	done
}

# Function for "smart" installation
pkg_install() {
	[ -f /etc/arch-release ] && [ -n "$1" ] && sudo pacman -S --needed --noconfirm "$1"
	[ ! -f /etc/arch-release ] && [ -n "$2" ] && sudo apt-get install -y "$2"
}

# ---- Install packages ----
install_packages(){
	echo -e "${YELLOW}Starting package installation...${NC}"
	# Compiler: Sakura Clang archive or the distribution's Clang/LLVM.
	# Rust and its bindings are always supplied by the distribution.
	pkg_install "bc" "bc"
	pkg_install "bison" "bison"
	pkg_install "make" "make"
	pkg_install "zstd" "zstd"
	pkg_install "clang" "clang"
	pkg_install "llvm" "llvm"
	pkg_install "lld" "lld"
	pkg_install "flex" "flex"
	pkg_install "openssl" "libssl-dev"
	pkg_install "openssl" "openssl"
	pkg_install "rust" "rustc"
	pkg_install "rust-src" "rust-src"
	pkg_install "bindgen" "bindgen"
	pkg_install "pahole" "dwarves"
	pkg_install "libclang" "libclang-dev"
	pkg_install "git" "git"
	pkg_install "curl" "curl"
	pkg_install "wget" "wget"
	pkg_install "zip" "zip"
	pkg_install "unzip" "unzip"
	pkg_install "jdk-openjdk" "default-jdk"
	echo -e "${GREEN}Necessary packages successfully installed.${NC}"
}

# ---- Clone AnyKernel3 ----
clone_anykernel3(){
	if [[ -e "$AK3_PATH" ]]; then
		[[ -d "$AK3_PATH" && ! -L "$AK3_PATH" && -f "$AK3_PATH/anykernel.sh" ]] || {
			echo -e "${RED}Existing AnyKernel directory is incomplete: $AK3_PATH${NC}" >&2
			return 1
		}
		echo -e "${GREEN}Using existing AnyKernel3: $AK3_PATH${NC}"
		return 0
	fi
	git clone --depth 1 --branch Nezuko git@github.com:Madara273/AnyKernel3.git "$AK3_PATH" ||
		git clone --depth 1 --branch Nezuko https://github.com/Madara273/AnyKernel3.git "$AK3_PATH"
}

# ---- Function to select and check the compiler and Rust tools ----
choose_compiler(){
	if [[ -n "${OP15R_COMPILER:-}" ]]; then
		COMPILER_CHOICE="$OP15R_COMPILER"
	else
		echo -e "${YELLOW}Choose compiler:${NC}"
		echo -e "${BLUE}1.👉 Sakura Clang 24${NC}"
		echo -e "${BLUE}2.👉 System Clang${NC}"
		read -t 5 -rp "Compiler (1/2, default 1): " COMPILER_CHOICE || true
		COMPILER_CHOICE="${COMPILER_CHOICE:-1}"
	fi
	case "$COMPILER_CHOICE" in
		1|sakura|Sakura) COMPILER_CHOICE=1; CURRENT_COMPILER="Sakura Clang 24" ;;
		2|system|System) COMPILER_CHOICE=2; CURRENT_COMPILER="System Clang" ;;
		*) echo -e "${RED}Unknown compiler selection: $COMPILER_CHOICE${NC}" >&2; return 1 ;;
	esac
}

check_tools(){
	echo -e "${YELLOW}Checking $CURRENT_COMPILER and system Rust...${NC}"
	if [[ "$COMPILER_CHOICE" == 1 ]]; then
		[[ -x "$LOCAL_TOOLCHAIN/bin/clang" ]] || { echo "Sakura Clang is missing" >&2; return 1; }
		export PATH="$LOCAL_TOOLCHAIN/bin:$SYSTEM_PATH"
	else
		export PATH="$SYSTEM_PATH"
	fi
	for tool in make clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip llvm-config rustc rustdoc bindgen pahole zip unzip git openssl keytool jarsigner sha256sum timeout; do
		command -v "$tool" >/dev/null 2>&1 || { echo "Missing tool: $tool" >&2; return 1; }
	done
	if [[ "$COMPILER_CHOICE" == 1 ]]; then
		[[ "$(command -v clang)" == "$LOCAL_TOOLCHAIN/bin/clang" ]] || { echo "Wrong Sakura Clang selected" >&2; return 1; }
	fi
	local rust_src
	rust_src="${OP15R_RUST_LIB_SRC:-}"
	if [[ -z "$rust_src" ]]; then
		rust_src="$(rustc --print sysroot)/lib/rustlib/src/rust/library"
		[[ -d "$rust_src" ]] || rust_src="$BUILD_ROOT/toolchains/rust-src-system/extracted/usr/lib/rustlib/src/rust/library"
	fi
	[[ -d "$rust_src" ]] || { echo "Rust source library missing; install rust-src or set OP15R_RUST_LIB_SRC" >&2; return 1; }
	export RUST_LIB_SRC="$rust_src"
	export RUSTC="$(command -v rustc)"
	export RUSTDOC="$(command -v rustdoc)"
	export BINDGEN="$(command -v bindgen)"
	export PAHOLE="$(command -v pahole)"
	local libclang
	libclang="${OP15R_LIBCLANG_PATH:-$(llvm-config --libdir)}"
	[[ -e "$libclang/libclang.so" ]] || { echo "libclang.so missing in $libclang; set OP15R_LIBCLANG_PATH" >&2; return 1; }
	export LIBCLANG_PATH="$libclang"
	echo -e "${GREEN}Compiler: $(clang --version | head -1); Rust: $(rustc --version)${NC}"
}

# ---- Function to create default kernel configuration ----
make_defconfig(){
	echo -e "${YELLOW}------------------------------${NC}"
	echo -e "${YELLOW} Generating kernel configuration...${NC}"
	make $FINAL_KERNEL_BUILD_PARA "$DEFCONFIG_NAME" || return 1
	# Match the working Image-only build, without modifying the source defconfig.
	scripts/config --file "$TARGET_OUT/.config" -d LTO_CLANG_THIN -d LTO_CLANG_FULL -e LTO_NONE -e CC_OPTIMIZE_FOR_PERFORMANCE -d CC_OPTIMIZE_FOR_PERFORMANCE_O3
	make $FINAL_KERNEL_BUILD_PARA olddefconfig || return 1
	for symbol in CONFIG_RUST=y CONFIG_UNICODE=y CONFIG_KSU=y CONFIG_KSU_SUSFS=y CONFIG_NR_CPUS=32; do
		grep -qx "$symbol" "$TARGET_OUT/.config" || { echo "Missing required config: $symbol" >&2; return 1; }
	done
	make $FINAL_KERNEL_BUILD_PARA rustavailable || return 1
	echo -e "${GREEN}Default kernel configuration created successfully.${NC}"
	echo -e "${YELLOW}------------------------------${NC}"
}

# ---- Function for building a kernel with color output and countdown ----
build_kernel() {
	echo -e "${YELLOW}---------------------------------------${NC}"
	echo -e "${YELLOW} Building the kernel...${NC}"
	echo -e "${YELLOW}---------------------------------------${NC}"

	set -e		# Exit on error
	set -o pipefail	# Catch errors or Ctrl+C inside the make | while pipeline

	# ---- Colored logger (stdout + log file) ----
	log_echo() {
		local color="$1"
		shift
		local message="$*"

		echo -e "${color}${message}${NC}"
		echo -e "${color}${message}${NC}" >> "$LOG_FILE"
	}

	# ---- Time tracking ----
	START_SEC=$(date +%s)

	TIME_COLOR="$BLUE"

	declare -A COLORS=(
		[normal]="$GREEN"
		[warning]="$PURPLE"
		[error]="$RED"
	)

	# ---- Kernel build with realtime log parsing ----
	make $FINAL_KERNEL_BUILD_PARA Image 2>&1 | while IFS= read -r line; do

		CURRENT_SEC=$(date +%s)
		ELAPSED_SEC=$(( CURRENT_SEC - START_SEC ))

		TIME_FMT=$(printf "%02d:%02d" $(( ELAPSED_SEC / 60 )) $(( ELAPSED_SEC % 60 )))

		level="normal"
		[[ $line =~ $WARNING_PATTERN ]] && level="warning"
		[[ $line =~ $ERROR_PATTERN   ]] && level="error"

		log_echo "${TIME_COLOR}${TIME_FMT} ${COLORS[$level]}" "$line"

	done

	# ---- Total build time ----
	END_SEC=$(date +%s)
	TOTAL_SEC=$(( END_SEC - START_SEC ))

	echo -e "${GREEN}Kernel build took $(( TOTAL_SEC / 60 ))m $(( TOTAL_SEC % 60 ))s${NC}" \
		| tee -a "$LOG_FILE"
}

# ---- Generate a secure keystore with a trusted cert for ZIP/APK signing ----
generate_secure_keystore() {
	[[ -f "$KEYSTORE" ]] && echo -e "${GREEN}✔ Keystore already exists: $KEYSTORE${NC}" && return

	echo -e "${YELLOW}Creating new keystore and full trust chain...${NC}"

	mkdir -p "$SIGNER_DIR" && chmod 700 "$SIGNER_DIR"

	PASS=$(openssl rand -hex 18)
	UNIQUE_ID=$(date +%Y%m%d_%H%M%S)
	KEYALIAS="tenzoKey_${UNIQUE_ID}"

	echo "$PASS" > "$PASSFILE"
	echo "$KEYALIAS" > "$ALIASFILE"
	chmod 600 "$PASSFILE" "$ALIASFILE"

	echo -e "${CYAN}Generating root CA...${NC}" &&
	openssl genrsa -out "$ROOTCA_KEY" 4096 &&
	openssl req -x509 -new -nodes -key "$ROOTCA_KEY" -sha256 -days 9125 \
		-out "$ROOTCA_CERT" -subj "/CN=Tenzo Root CA/O=Madara273/C=UA" ||
	{ echo -e "${RED}✘ Root CA generation failed${NC}"; return 1; }

	echo -e "${CYAN}Generating Tenzo keypair and CSR...${NC}" &&
	openssl genrsa -out "$TENZO_KEY" 4096 &&
	openssl req -new -key "$TENZO_KEY" -out "$CSR_FILE" \
		-subj "/CN=Tenzo, OU=Root, O=Madara273, L=UA, ST=Ukraine, C=UA" ||
	{ echo -e "${RED}✘ Keypair or CSR failed${NC}"; return 1; }

	openssl x509 -req -in "$CSR_FILE" -CA "$ROOTCA_CERT" -CAkey "$ROOTCA_KEY" \
		-CAcreateserial -out "$TENZO_CERT" -sha256 -days 365 || \
	{ echo -e "${RED}✘ Signing failed${NC}"; return 1; }

	echo -e "${CYAN}Exporting to PKCS#12...${NC}" &&
	openssl pkcs12 -export \
		-inkey "$TENZO_KEY" \
		-in "$TENZO_CERT" \
		-certfile "$ROOTCA_CERT" \
		-out "$P12_FILE" \
		-password pass:"$PASS" \
		-name "$KEYALIAS" ||
	{ echo -e "${RED}✘ PKCS#12 export failed${NC}"; return 1; }

	keytool -importkeystore \
		-srckeystore "$P12_FILE" -srcstoretype PKCS12 -srcstorepass "$PASS" \
		-destkeystore "$KEYSTORE" -deststoretype PKCS12 -deststorepass "$PASS" \
		-alias "$KEYALIAS" -noprompt || \
	{ echo -e "${RED}✘ PKCS12 import failed${NC}"; return 1; }

	keytool -importcert -trustcacerts -alias "rootCA_${UNIQUE_ID}" -file "$ROOTCA_CERT" \
		-keystore "$KEYSTORE" -storepass "$PASS" -noprompt ||
	{ echo -e "${RED}✘ Failed to add rootCA to keystore${NC}"; return 1; }

	# Keep this signing key local; never modify the host Java truststore.
	echo -e "${GREEN}✔ Keystore created: $KEYSTORE${NC}"
	show_fingerprint
}

# ----  SIGN ZIP FILE ----
sign_zip() {
	ZIP="$1"
	OUT="$2"

	[[ -f "$ZIP" ]] || {
		echo -e "${RED}✘ ZIP file not found: $ZIP${NC}"
		exit 1
	}

	generate_secure_keystore

	PASS=$(cat "$PASSFILE")
	KEYALIAS=$(cat "$ALIASFILE")

	cp "$ZIP" "$OUT" || return 1

	echo -e "${CYAN}Signing ZIP with timestamp (up to 30 seconds)...${NC}"
	SIGNING_OUTPUT=$(timeout -k 5s 30s jarsigner -keystore "$KEYSTORE" -storepass "$PASS" -keypass "$PASS" \
		-sigalg SHA256withRSA -digestalg SHA-256 \
		-tsa http://timestamp.digicert.com \
		"$OUT" "$KEYALIAS" 2>&1) || true
	if [[ "$SIGNING_OUTPUT" != *"jar signed."* ]]; then
		echo -e "${YELLOW}Timestamp server unavailable or timed out; signing without timestamp.${NC}"
		cp "$ZIP" "$OUT" || return 1
		SIGNING_OUTPUT=$(jarsigner -keystore "$KEYSTORE" -storepass "$PASS" -keypass "$PASS" \
			-sigalg SHA256withRSA -digestalg SHA-256 "$OUT" "$KEYALIAS" 2>&1) || true
	fi

	echo "$SIGNING_OUTPUT" | grep -q "jar signed." &&
	{
		echo -e "${GREEN}✔ Signed successfully: $OUT${NC}"
		echo "$SIGNING_OUTPUT" | grep -q "The timestamp will expire" &&
			echo -e "${YELLOW}$(echo "$SIGNING_OUTPUT" | grep "The timestamp will expire")${NC}"
	} || {
		echo -e "${RED}❌ Signing failed!${NC}"
		echo "$SIGNING_OUTPUT"
		exit 1
	}
}

# ---- SHOW FINGERPRINT ----
show_fingerprint() {
	[[ -f "$KEYSTORE" && -f "$PASSFILE" && -f "$ALIASFILE" ]] &&
	{
		PASS=$(cat "$PASSFILE")
		KEYALIAS=$(cat "$ALIASFILE")
		echo -e "${CYAN}SHA256 Fingerprint:${NC}"
		keytool -list -v -keystore "$KEYSTORE" -storepass "$PASS" -alias "$KEYALIAS" 2>/dev/null | grep "SHA256:"
	} || {
		echo -e "${RED}✘ Cannot display fingerprint. Keystore or data missing.${NC}"
	}
}

# ---- Generate the Image-only flashable archive and sign it ----
generate_flashable() {
	echo -e "${YELLOW}------------------------------${NC}"
	echo -e "${YELLOW} Generating flashable kernel ${NC}"
	echo -e "${YELLOW}------------------------------${NC}"

	[[ -s "$TARGET_KERNEL_FILE" ]] || { echo "Image missing: $TARGET_KERNEL_FILE" >&2; return 1; }
	[[ -f "$AK3_PATH/anykernel.sh" ]] || { echo "AnyKernel3 is incomplete: $AK3_PATH" >&2; return 1; }
	cp "$TARGET_KERNEL_FILE" "$AK3_PATH/Image" || return 1
	# The package only replaces boot Image; no device trees or external modules.
	cd "$AK3_PATH" || return 1
	local flashable_zip="Nezuko-$CURRENT_TIME.zip"
	local signed_zip="Nezuko-$CURRENT_TIME-signed.zip"
	zip -q -r "$flashable_zip" . \
		-x "./.git/*" "./build.log" "./defconfig" "./changelog.txt" "./kernel-changelog.txt" "./Nezuko-*.zip" \
		   "./$flashable_zip" "./$signed_zip" || return 1
	unzip -tq "$flashable_zip" >/dev/null || return 1
	echo -e "${YELLOW} Signing ZIP file securely... ${NC}"
	sign_zip "$flashable_zip" "$signed_zip" || return 1
	unzip -tq "$signed_zip" >/dev/null || return 1
	local image_hash packaged_hash
	image_hash=$(sha256sum "$TARGET_KERNEL_FILE" | cut -d' ' -f1)
	packaged_hash=$(unzip -p "$signed_zip" Image | sha256sum | cut -d' ' -f1)
	[[ "$image_hash" == "$packaged_hash" ]] || { echo "Packaged Image hash differs from built Image" >&2; return 1; }
	echo -e "${GREEN}✔ Flashable signed zip ready: $AK3_PATH/$signed_zip${NC}"
	cd "$KERNEL_DIR" || return 1
}

# ---- Save kernel configuration (Always Save) ----
save_defconfig() {
	echo -e "${YELLOW}------------------------------${NC}"
	echo -e "${YELLOW} Saving kernel configuration...${NC}"
	echo -e "${YELLOW}------------------------------${NC}"

	[ -f "$TARGET_OUT/.config" ] && {
		cp "$TARGET_OUT/.config" "$AK3_PATH/defconfig"
		END_SEC=$(date +%s)
		COST_SEC=$((END_SEC - START_SEC))
		echo -e "${YELLOW}Completed. Kernel configuration saved to ${AK3_PATH}/defconfig${NC}"
		echo -e "${YELLOW}Kernel configuration save took ${COST_SEC} seconds.${NC}"
	} || echo -e "${RED}Error: '$TARGET_OUT/.config' not found. Cannot save configuration.${NC}"
}

# ---- Prepare the reusable external output directory ----
clean() {
	[[ "$TARGET_OUT" == "$BUILD_ROOT/out" && "$TARGET_OUT" != "$BUILD_ROOT/" ]] || {
		echo "Unsafe output path: $TARGET_OUT" >&2; return 1;
	}
	[[ ! -L "$TARGET_OUT" ]] || { echo "Output is a symlink: $TARGET_OUT" >&2; return 1; }
	[[ ! -e "$TARGET_OUT" || -d "$TARGET_OUT" ]] || { echo "Output is not a directory: $TARGET_OUT" >&2; return 1; }
	mkdir -p "$TARGET_OUT" || return 1
	if [[ -f "$TARGET_OUT/.config" ]]; then
		make $FINAL_KERNEL_BUILD_PARA clean || return 1
	fi
	echo -e "${GREEN}Output: $TARGET_OUT${NC}"
}

# ---- Setup colour for the script ----
purple='\033[0;35m'

# Function to show an informational message
msg() {
	echo -e "\e[1;32m$*\e[0m"
}

[Aerr() {
	echo -e "\e[1;41m$*\e[0m"
	exit 1
}

# ---- Function to create a changelog file with the last 200 commits ----
create_changelog() {
	git log -n 200 --pretty=format:"- %h - %s (%an)" > "$AK3_PATH/changelog.txt"
	msg "Changelog saved to $AK3_PATH/changelog.txt"
}

# ---- End Build Info ----
display_kernel_version_info() {
	echo -e "${GREEN}===================END_BUILD=================${NC}"
	echo -e "${PURPLE}***************Nezuko-Kernel**************${NC}"
	echo -e "USER: $KBUILD_USER"
	echo -e "HOST: $KBUILD_HOST"
	echo -e "Last commit (name): $(git log -1 --pretty=format:%s)"
	echo -e "Last commit (hash): $(git log -1 --pretty=format:%H)"
	echo -e "Kernel release: $(cat "$TARGET_OUT/include/config/kernel.release")"
	echo -e "CONFIG_LOCALVERSION: $(grep -E '^CONFIG_LOCALVERSION=' "$TARGET_OUT/.config" | cut -d= -f2-)"
	echo -e "Compiler: $(clang --version | head -1)"
	echo -e "Rust: $(rustc --version)"
	echo -e "${PURPLE}**********************************************${NC}"
}

setup_toolchains() {
	[[ "$COMPILER_CHOICE" == 1 ]] || return 0
	echo -e "${YELLOW}Setting up Sakura Clang in $LOCAL_TOOLCHAIN...${NC}"
	[[ -x "$LOCAL_TOOLCHAIN/bin/clang" ]] && return 0
	for tool in curl tar zstd; do
		command -v "$tool" >/dev/null 2>&1 || { echo "Missing tool for Sakura Clang setup: $tool" >&2; return 1; }
	done
	mkdir -p "$LOCAL_TOOLCHAIN" || return 1
	local archive="$BUILD_ROOT/toolchains/sakura-clang-24.0.0.tar.zst"
	if [[ ! -s "$archive" ]]; then
		mkdir -p "$(dirname "$archive")" || return 1
		curl -fL --retry 3 -o "$archive" \
			"https://github.com/Madara273/Sakura-Clang-Compiler/releases/download/Sakura-Clang-R01/sakura-clang-24.0.0.tar.zst" || return 1
	fi
	tar --zstd -xf "$archive" -C "$LOCAL_TOOLCHAIN" || return 1
	[[ -x "$LOCAL_TOOLCHAIN/bin/clang" ]] || { echo "Sakura Clang extraction failed" >&2; return 1; }
}

# ---- Kernel compilation function ----
compile_kernel() {
	trap 'echo -e "${RED}Build interrupted!${NC}"; exit 1' INT TERM
	ascii_art_logo
	choose_compiler || return 1
	setup_toolchains || return 1
	check_tools || return 1
	clean || return 1
	clone_anykernel3 || return 1
	make_defconfig || return 1
	display_build_info
	create_changelog || return 1
	save_defconfig || return 1
	{
		build_kernel &&
		generate_flashable &&
		display_kernel_version_info
	} || {
		echo -e "${RED}Error: Kernel build failed.${NC}"
		return 1
	}
}

case "${OP15R_ACTION:-menu}" in
	menu) choose_action || exit $? ;;
	check) choose_compiler && setup_toolchains && check_tools || exit $? ;;
	build) compile_kernel || exit $? ;;
	*) echo "Unknown OP15R_ACTION: $OP15R_ACTION" >&2; exit 1 ;;
esac

echo -e "${GREEN}Done.${NC}"

# END CUSTOM BUILD KERNEL SCRIPTS
