#!/bin/bash

set -e
set -o pipefail

echo 'Getting wpnonce'
__wpnonce="$(curl 'https://support.purevpn.com/vpn-servers' -s | grep -oE 'id="_wpnonce" name="_wpnonce" value="[^"]*"' | sed -e 's/.*value="\(.*\)"/\1/')"

echo 'Getting Page'
curl -X POST -d 'action=load_servers_list' -d "_wpnonce=${__wpnonce}" 'https://support.purevpn.com/wp-admin/admin-ajax.php' >'page.html'

__xml_inter="$(cat 'page.html' | sed '1,2d')"

xmllint --xpath "/table/tbody/tr[@class='parent']/td[@style='width:180px;']/text()" - <<<"${__xml_inter}" |
    sed -e 's/^ *//' -e 's/ *$//' -e '/^$/d' >countries.txt

n=0

__protocols=('PPTP' 'L2TP' 'SSTP' 'IKEV' 'IPSEC' 'TCP' 'UDP')

echo 'Processing Page'

# Read country servers
while read -r __country; do

    echo "${__country}"

    n=$((n + 1))

    __cities="$(

        xmllint --xpath "/table/tbody[${n}]/tr[@class='cchild']" - <<<"${__xml_inter}" | (
            echo '<root>'
            cat
            echo '</root>'
        ) |
            xmllint --xpath "/root/tr/td[@style='width:180px;']/text()" -

    )"

    set -o noglob
    IFS=$'\n' __cities_array=(${__cities})
    set +o noglob

    __target="./servers/${__country}"

    if ! [ -d "${__target}" ]; then
        mkdir -p "${__target}"
    fi

    __tmp="$(
        xmllint --xpath "/table/tbody[${n}]/tr[@class='parent']/td[not(@style='width:180px;')]" - <<<"${__xml_inter}" | (
            echo '<root>'
            cat
            echo '</root>'
        )
    )"

    __servers="$(

        echo "${__tmp}" |
            xmllint --xpath "/root/td/span[position() > 1]/text()" - |
            sed -e 's|^N/A$|N/A\n|' |
            while mapfile -t -n 2 ary && ((${#ary[@]})); do
                echo "${ary[0]}${ary[1]}"
            done

    )"

    __avail="$(

        echo "${__tmp}" |
            xmllint --xpath "/root/td/span[1]/@title" - |
            sed -e 's/.*"\(.*\)"/\1/'

    )"

    set -o noglob
    IFS=$'\n' __avail_array=(${__avail})
    IFS=$'\n' __servers_array=(${__servers})
    set +o noglob

    (
        echo '"Protocol","Address","Availability"'
        for i in "${!__servers_array[@]}"; do
            echo "\"${__protocols[${i}]}\",\"${__servers_array[${i}]}\",\"${__avail_array[${i}]}\""
        done
    ) >"${__target}.csv"

    for i in "${!__cities_array[@]}"; do
        __city="${__cities_array[${i}]}"
        echo "    ${__city}"

        ix=$((i + 1))

        __tmp="$(
            xmllint --xpath "/table/tbody[${n}]/tr[@class='cchild'][${ix}]/td[not(@style='width:180px;')]" - <<<"${__xml_inter}" | (
                echo '<root>'
                cat
                echo '</root>'
            )
        )"

        __tmp_avail="$(
            echo "${__tmp}" |
                xmllint --xpath "/root/td/span[1]/@title" - |
                sed -e 's/.*"\(.*\)".*/\1/'
        )"

        __tmp_servers="$(
            echo "${__tmp}" |
                xmllint --xpath "/root/td/span[position() > 1]/text()" - |
                sed -e 's|^N/A$|N/A\n|' |
                while mapfile -t -n 2 ary && ((${#ary[@]})); do
                    echo "${ary[0]}${ary[1]}"
                done
        )"

        set -o noglob
        IFS=$'\n' __tmp_avail_array=(${__tmp_avail})
        IFS=$'\n' __tmp_servers_array=(${__tmp_servers})
        set +o noglob

        (
            echo '"Protocol","Address","Availability"'
            for __i in "${!__tmp_servers_array[@]}"; do
                echo "\"${__protocols[${__i}]}\",\"${__tmp_servers_array[${__i}]}\",\"${__tmp_avail_array[${__i}]}\""
            done
        ) >"${__target}/${__city}.csv"

    done

    echo

done \
    <'countries.txt'

exit
