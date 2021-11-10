#!/bin/bash -e

cmd_dir=`dirname $0`

function setupTmp(){
    tmp_dir=$cmd_dir'/tmp/'
    mkdir -p $tmp_dir
    timestamp=$(date +%Y%m%d%H%M%S)
    tmp_id=${timestamp}'_'$(ls -l $tmp_dir | grep $timestamp | wc -l)
    tmp=${tmp_dir}${tmp_id}'/'
    mkdir -p $tmp
}

function rmExpired(){
    ts_sec=$(date +%s)
    expired_sec=$(($ts_sec-60*60))
    expired_date=$(date --date=@$expired_sec +%Y%m%d%H%M%S)
    for d in `ls $tmp_dir`; do
        d_date=${d:0:14}
        if [[ $d_date =~ ^[0-9]+$ ]]; then
            [ $d_date -lt $expired_date ] && rm -rdf ${tmp_dir}${d} || :
        fi
    done
}

setupTmp
rmExpired

def_path=${1:-./bbtdef.json}
if [ ! -f "$def_path" ]; then
    echo "Definition file is not found." >&2
    end 1
fi

shjp=${cmd_dir}/app/src/sh/shjp.sh
$shjp $def_path > ${tmp}def_comp
$shjp -g ${tmp}def_comp operations > ${tmp}def_operations

mkdir -p ${tmp}env/
mkdir -p ${tmp}resource/
cp $def_path ${tmp}bbtdef.json
for n in `$shjp -g ${tmp}def_comp need`; do
    cp -r ./$n ${tmp}env/
done
cp -r "./$($shjp -g ${tmp}def_comp resource)" ${tmp}resource/

docker build -t cmdbbt $cmd_dir

run_args="\
    --rm \
    --name cmdbbt \
    -v `realpath $tmp`:/mnt/work \
    cmdbbt"
os_name=$(uname)
if [[ ${os_name,,} =~ ^(mingw).* ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker run $run_args
else
    docker run $run_args
fi

rm -rdf ${tmp}