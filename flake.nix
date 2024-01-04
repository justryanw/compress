{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    perSystem = { pkgs, system, ... }: {
      packages.default = pkgs.writeShellScriptBin "compress" ''
              # Re-encode a video to a target size in MB.
        # Example:
        #    ./this_script.sh video.mp4 15

        T_SIZE="$2" # target size in MB
        T_FILE="''${1%.*}-$2MB.mp4" # filename out

        # Original duration in seconds
        O_DUR=$(\
            ${pkgs.ffmpeg}/bin/ffprobe \
            -v error \
            -show_entries format=duration \
            -of csv=p=0 "$1")

        # Original audio rate
        O_ARATE=$(\
            ${pkgs.ffmpeg}/bin/ffprobe \
            -v error \
            -select_streams a:0 \
            -show_entries stream=bit_rate \
            -of csv=p=0 "$1")

        # Original audio rate in KiB/s
        O_ARATE=$(\
            awk \
            -v arate="$O_ARATE" \
            'BEGIN { printf "%.0f", (arate / 1024) }')

        # Target size is required to be less than the size of the original audio stream
        T_MINSIZE=$(\
            awk \
            -v arate="$O_ARATE" \
            -v duration="$O_DUR" \
            'BEGIN { printf "%.2f", ( (arate * duration) / 8192 ) }')

        # Equals 1 if target size is ok, 0 otherwise
        IS_MINSIZE=$(\
            awk \
            -v size="$T_SIZE" \
            -v minsize="$T_MINSIZE" \
            'BEGIN { print (minsize < size) }')

        # Give useful information if size is too small
        if [[ $IS_MINSIZE -eq 0 ]]; then
            printf "%s\n" "Target size ''${T_SIZE}MB is too small!" >&2
            printf "%s %s\n" "Try values larger than" "''${T_MINSIZE}MB" >&2
            exit 1
        fi

        # Set target audio bitrate
        T_ARATE=$O_ARATE


        # Calculate target video rate - MB -> KiB/s
        T_VRATE=$(\
            awk \
            -v size="$T_SIZE" \
            -v duration="$O_DUR" \
            -v audio_rate="$O_ARATE" \
            'BEGIN { print  ( ( size * 8192.0 ) / ( 1.048576 * duration ) - audio_rate) }')

        # Perform the conversion
        ${pkgs.ffmpeg}/bin/ffmpeg \
            -y \
            -i "$1" \
            -c:v libx264 \
            -b:v "$T_VRATE"k \
            -pass 1 \
            -an \
            -f mp4 \
            /dev/null \
        && \
        ${pkgs.ffmpeg}/bin/ffmpeg \
            -i "$1" \
            -c:v libx264 \
            -b:v "$T_VRATE"k \
            -pass 2 \
            -c:a aac \
            -b:a "$T_ARATE"k \
            "$T_FILE"
      '';
    };
  };
}
