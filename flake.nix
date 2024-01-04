{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    perSystem = { pkgs, system, ... }: {
      packages.default = pkgs.writeShellScriptBin "compress" ''
        file=$1
        output="''${1%.*}-$2MB.mp4"
        target_size_mb=$2  # target size in MB
        target_size=$(( $target_size_mb * 1000 * 1000 * 8 )) # target size in bits
        length=`${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file"`
        length_round_up=$(( ''${length%.*} + 1 ))
        total_bitrate=$(( $target_size / $length_round_up ))
        audio_bitrate=$(( 128 * 1000 )) # 128k bit rate
        video_bitrate=$(( $total_bitrate - $audio_bitrate ))
        max_bitrate=$((4 * 1000 * 1000))
        video_bitrate_limited=$(( $video_bitrate > $max_bitrate ? $max_bitrate : $video_bitrate))
        echo "Video Bitrate $(($video_bitrate / 1000)) Kbps"
        ${pkgs.ffmpeg}/bin/ffmpeg -i "$file" -vf scale=-1:720 -b:v $video_bitrate_limited -maxrate:v $video_bitrate_limited -bufsize:v $(( $target_size / 20 )) -b:a $audio_bitrate "$output"
      '';
    };
  };
}
