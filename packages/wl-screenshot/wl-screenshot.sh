set -o errexit
grim -g "$(slurp)" -t ppm - | satty --filename -
