#!/usr/bin/env bash

set -euxo pipefail

cd -P "$(dirname -- "${0}")"

if [ ! -x './python2/bin/python2' ]; then
	wget https://www.python.org/ftp/python/2.7.5/Python-2.7.5.tgz -O ./Python-2.7.5.tgz
	tar xf ./Python-2.7.5.tgz
	rm -rf ./Python-2.7.5.tgz
	pushd ./Python-2.7.5
	./configure prefix="${PWD}/../python2"
	make install
	popd
	rm -rf ./Python-2.7.5
fi

if [ ! -x './pigz/pigz' ]; then
	git clone --depth 1 'https://github.com/madler/pigz' pigz
	pushd pigz
	make
	popd
fi

rm -rf anaconda
git clone --depth 1 'https://github.com/rhinstaller/anaconda' -b 'f31-release' anaconda
pushd anaconda
sed -i \
	-e 's/self.add_check(verify_unlocked_devices_have_key)/#self.add_check(verify_unlocked_devices_have_key)/' \
	'./pyanaconda/storage/checker.py'
../python2/bin/python2 ./scripts/makeupdates
popd

cp ./anaconda/updates.img ./kickstart/updates.img
printf '\033[32mDone, no errors, serving files now on port 8080\033[m\n'
pushd ./kickstart
../python2/bin/python2 -m SimpleHTTPServer 8080
