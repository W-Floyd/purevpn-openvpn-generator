#!/bin/bash

if [ -d './configs' ]; then
    rm -r './configs'
fi

pushd './servers/' || {
    echo 'Servers not checked, exiting'
    exit 1
}

(
    grep -rlE '"TCP",".*"Available"'
    grep -rlE '"UDP",".*"Available"'
) | sort | uniq | while read -r __file; do
    while read -r __line; do
        __proto="${__line% *}"
        __port="${__line/* /}"
        __target="../configs/${__file%.*}_${__proto,,}.ovpn"
        mkdir -p "$(dirname "${__target}")"
        __server="$(grep -oE "\"${__proto}\",\".*\"Available\"" "${__file}" | sed -e 's/.*","\(.*\)",".*/\1/')"
        sed "../templates/template.ovpn" -e "s|__PROTO__|${__proto,,}|" -e "s|__ADDRESS__|${__server}|" -e "s|__PORT__|${__port}|" >"${__target}"
    done <<<'TCP 80
UDP 53'

done

popd || {
    echo 'Something horrible just happened.'
    exit 1
}

exit
