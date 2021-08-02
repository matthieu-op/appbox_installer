#!/usr/bin/env bash
# Appbox installer for Ubuntu 20.04
#
# Just run this on your Ubuntu VNC app via SSH or in the terminal (Applications > Terminal Emulator) using:
# sudo bash -c "bash <(curl -Ls https://raw.githubusercontent.com/coder8338/appbox_installer/Ubuntu-20.04/appbox_installer.sh)"
#
# We do not work for appbox, we're a friendly community helping others out, we will try to keep this as uptodate as possible!

set -e
set -u

export DEBIAN_FRONTEND=noninteractive

run_as_root() {
    if ! whoami | grep -q 'root'; then
        echo "Please enter your user password, then run this script again!"
        sudo -s
        return 0
    fi
}


configure_nginx() {
    NAME=${1}
    PORT=${2}
    OPTION=${3:-default}
    if ! grep -q "/${NAME} {" /etc/nginx/sites-enabled/default; then
        sed -i '/server_name _/a \
        location /'${NAME}' {\
                proxy_pass http://127.0.0.1:'${PORT}';\
        }' /etc/nginx/sites-enabled/default

        if [ "${OPTION}" == 'subfilter' ]; then
            sed -i '/location \/'${NAME}' /a \
                sub_filter "http://"  "https://";\
                sub_filter_once off;' /etc/nginx/sites-enabled/default
        fi
    fi
    pkill -HUP nginx
    url_output "${NAME}"
}

url_output() {
    NAME=${1}
    APPBOX_USER=$(echo "${HOSTNAME}" | awk -F'.' '{print $2}')
    echo -e "\n\n\n\n\n
        Installation sucessful! Please point your browser to:
        \e[4mhttps://${HOSTNAME}/${NAME}\e[39m\e[0m
        
        You can continue the configuration from there.
        \e[96mMake sure you protect the app by setting up a username/password in the app's settings!\e[39m
        
        \e[91mIf you want to use another appbox app in the settings of ${NAME}, make sure you access it on port 80, and without https, for example:
        \e[4mhttp://rutorrent.${APPBOX_USER}.appboxes.co\e[39m\e[0m
        \e[95mIf you want to access Plex from one of these installed apps use port 32400 for example:
        \e[4mhttp://plex.${APPBOX_USER}.appboxes.co:32400\e[39m\e[0m
        
        That's because inside this container, we don't go through the appbox proxy! \n\n\n\n\n\n"
}

setup_radarr() {
    configure_nginx 'radarr' '7878'
}

setup_sonarr() {
    configure_nginx 'sonarr' '8989'
}

setup_sickchill() {
    configure_nginx 'sickchill' '8081'
}

setup_jackett() {
    configure_nginx 'jackett' '9117'
}

setup_couchpotato() {
    configure_nginx 'couchpotato' '5050'
}

setup_nzbget() {
    configure_nginx 'nzbget' '6789'
}

setup_sabnzbdplus() {
    configure_nginx 'sabnzbd' '9090'
}

setup_ombi() {
    configure_nginx 'ombi' '5000'
}

setup_lidarr() {
    configure_nginx 'lidarr' '8686'
}

setup_organizr() {

    echo "Configuring PHP to use sockets"

    if [ ! -f /etc/php/7.4/fpm/pool.d/www.conf.original ]; then
        cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.original
    fi

    # TODO: Check if settings catch
    # enable PHP-FPM
    sed -i "s#www-data#appbox#g" /etc/php/7.4/fpm/pool.d/www.conf
    sed -i "s#;listen.mode = 0660#listen.mode = 0777#g" /etc/php/7.4/fpm/pool.d/www.conf
    # set our recommended defaults
    sed -i "s#pm = dynamic#pm = ondemand#g" /etc/php/7.4/fpm/pool.d/www.conf
    sed -i "s#pm.max_children = 5#pm.max_children = 4000#g" /etc/php/7.4/fpm/pool.d/www.conf
    sed -i "s#pm.start_servers = 2#;pm.start_servers = 2#g" /etc/php/7.4/fpm/pool.d/www.conf
    sed -i "s#;pm.process_idle_timeout = 10s;#pm.process_idle_timeout = 10s;#g" /etc/php/7.4/fpm/pool.d/www.conf
    sed -i "s#;pm.max_requests = 500#pm.max_requests = 0#g" /etc/php/7.4/fpm/pool.d/www.conf
    chown -R appbox:appbox /var/lib/php

        cat << EOF > /etc/nginx/sites-enabled/organizr
# V0.0.4
server {
(
  listen 8009;
  root /home/appbox/appbox_installer/organizr;
  index index.html index.htm index.php;

  server_name _;
  client_max_body_size 0;

  # Real Docker IP
  # Make sure to update the IP range with your Docker IP subnet
  real_ip_header X-Forwarded-For;
  #set_real_ip_from 172.17.0.0/16;
  real_ip_recursive on;

  # Deny access to Org .git directory
  location ~ /\.git {
    deny all;
  }

  location /organizr {
    try_files \$uri \$uri/ /organizr/index.html /organizr/index.php?\$args =404;
  }

  location /organizr/api/v2 {
    try_files \$uri /organizr/api/v2/index.php\$is_args\$args;
  }

  location ~ \.php$ {
    fastcgi_split_path_info ^(.+?\.php)(\/.*|)$;
    fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_buffers 32 32k;
    fastcgi_buffer_size 32k;
  }
}
EOF

    chown -R appbox:appbox /home/appbox/appbox_installer/organizr /run/php
    RUNNER=$(cat << EOF
#!/bin/execlineb -P

# Redirect stderr to stdout.
fdmove -c 2 1

/usr/sbin/php-fpm7.4 -F
EOF
)

    configure_nginx 'organizr/' '8009'
}

setup_nzbhydra2() {
    configure_nginx 'nzbhydra2' '5076'
}

setup_bazarr() {
    configure_nginx 'bazarr' '6767'
}

setup_flexget() {
    configure_nginx 'flexget' '9797'
}

setup_filebot() {
    echo -e "\n\n\n\n\n
    FileBot doesn't require Nginx."
}

setup_synclounge() {
    configure_nginx 'synclounge/' '8088'
}

setup_medusa() {
    configure_nginx 'medusa' '8082' 'subfilter'
}

setup_lazylibrarian() {
    configure_nginx 'lazylibrarian' '5299'
}

setup_pyload() {
    configure_nginx 'pyload' '8000'
    echo -e "\n\n\n\n\n
    The default user for pyload is: admin
    The default password for pyload is: pyload"
}

setup_ngpost() {
    echo -e "\n\n\n\n\n
    Ngpost doesn't require Nginx. Please launch ngpost using the \"Applications\" menu on the top left of your screen."
}

setup_komga() {
    configure_nginx 'komga' '8443'
}

setup_ombiv4() {
    configure_nginx 'ombiv4' '6050'
}

setup_readarr() {
    configure_nginx 'readarr' '8787'
}

setup_overseerr() {
    if ! grep -q "overseerr {" /etc/nginx/sites-enabled/default; then
        sed -i '/server_name _/a \
        location /overseerr {\
                set $app "overseerr";\
                # Remove /overseerr path to pass to the app\
                rewrite ^/overseerr/?(.*)$ /$1 break;\
                proxy_pass http://127.0.0.1:5055; # NO TRAILING SLASH\
\
                # Redirect location headers\
                proxy_redirect ^ /$app;\
                proxy_redirect /setup /$app/setup;\
                proxy_redirect /login /$app/login;\
\
                # Sub filters to replace hardcoded paths\
                proxy_set_header Accept-Encoding "";\
                sub_filter_once off;\
                sub_filter_types *;\
                sub_filter '\''href="/"'\'' '\''href="/$app"'\'';\
                sub_filter '\''href="/login"'\'' '\''href="/$app/login"'\'';\
                sub_filter '\''href:"/"'\'' '\''href:"/$app"'\'';\
                sub_filter '\''/_next'\'' '\''/$app/_next'\'';\
                sub_filter '\''/api/v1'\'' '\''/$app/api/v1'\'';\
                sub_filter '\''/login/plex/loading'\'' '\''/$app/login/plex/loading'\'';\
                sub_filter '\''/images/'\'' '\''/$app/images/'\'';\
                sub_filter '\''/android-'\'' '\''/$app/android-'\'';\
                sub_filter '\''/apple-'\'' '\''/$app/apple-'\'';\
                sub_filter '\''/favicon'\'' '\''/$app/favicon'\'';\
                sub_filter '\''/logo.png'\'' '\''/$app/logo.png'\'';\
                sub_filter '\''/site.webmanifest'\'' '\''/$app/site.webmanifest'\'';\
        }' /etc/nginx/sites-enabled/default
    fi
    pkill -HUP nginx
    url_output "overseerr"
}

setup_requestrr() {
    configure_nginx 'requestrr' '4545'
}

install_prompt() {
    echo "Welcome to the install script, please select one of the following options to install:
    
    1) radarr
    2) sonarr
    3) sickchill
    4) jackett
    5) couchpotato
    6) nzbget
    7) sabnzbdplus
    8) ombi
    9) lidarr
    10) organizr
    11) nzbhydra2
    12) bazarr
    13) flexget
    14) filebot
    15) synclounge
    16) medusa
    17) lazylibrarian
    18) pyload
    19) ngpost
    20) komga
    21) ombiv4
    22) readarr
    23) overseerr
    24) requestrr
    "
    echo -n "Enter the option and press [ENTER]: "
    read OPTION
    echo

    case "$OPTION" in
        1|radarr)
            echo "Setting up radarr.."
            setup_radarr
            ;;
        2|sonarr)
            echo "Setting up sonarr.."
            setup_sonarr
            ;;
        3|sickchill)
            echo "Setting up sickchill.."
            setup_sickchill
            ;;
        4|jackett)
            echo "Setting up jackett.."
            setup_jackett
            ;;
        5|couchpotato)
            echo "Setting up couchpotato.."
            setup_couchpotato
            ;;
        6|nzbget)
            echo "Setting up nzbget.."
            setup_nzbget
            ;;
        7|sabnzbdplus)
            echo "Setting up sabnzbdplus.."
            setup_sabnzbdplus
            ;;
        8|ombi)
            echo "Setting up ombi.."
            setup_ombi
            ;;
        9|lidarr)
            echo "Setting up lidarr.."
            setup_lidarr
            ;;
        10|organizr)
            echo "Setting up organizr.."
            setup_organizr
            ;;
        11|nzbhydra2)
            echo "Setting up nzbhydra2.."
            setup_nzbhydra2
            ;;
        12|bazarr)
            echo "Setting up bazarr.."
            setup_bazarr
            ;;
        13|flexget)
            echo "Setting up flexget.."
            setup_flexget
            ;;
        14|filebot)
            echo "Setting up filebot.."
            setup_filebot
            ;;
        15|synclounge)
            echo "Setting up synclounge.."
            setup_synclounge
            ;;
        16|medusa)
            echo "Setting up medusa.."
            setup_medusa
            ;;
        17|lazylibrarian)
            echo "Setting up lazylibrarian.."
            setup_lazylibrarian
            ;;
        18|pyload)
            echo "Setting up pyload.."
            setup_pyload
            ;;
        19|ngpost)
            echo "Setting up ngpost.."
            setup_ngpost
            ;;
        20|komga)
            echo "Setting up komga.."
            setup_komga
            ;;
        21|ombiv4)
            echo "Setting up ombi v4.."
            setup_ombiv4
            ;;
        22|readarr)
            echo "Setting up readarr.."
            setup_readarr
            ;;
        23|overseerr)
            echo "Setting up overseerr.."
            setup_overseerr
            ;;
        24|requestrr)
            echo "Setting up requestrr.."
            setup_requestrr
            ;;
        *) 
            echo "Sorry, that option doesn't exist, please try again!"
            return 1
        ;;
        esac
}

run_as_root
sed -i 's/www-data/appbox/g' /etc/nginx/nginx.conf
echo -e "\nEnsuring appbox_installer folder exists..."
mkdir -p /home/appbox/appbox_installer
echo -e "\nUpdating apt packages..."
if ! apt update >/dev/null 2>&1; then
    echo -e "\napt update failed! Please fix repo issues and try again!"
    exit
fi
until install_prompt ; do : ; done
