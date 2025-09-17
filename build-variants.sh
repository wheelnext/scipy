#!/bin/sh

set -ex

pip config set global.extra-index-url https://pypi.anaconda.org/mgorny/simple

LABEL=${BLAS:-openblas}
case ${BLAS:-openblas} in
	openblas)
		bash tools/wheels/cibw_before_build_linux.sh "${PWD}"
		export PKG_CONFIG_PATH=${PWD}
		;;
	mkl)
		pip install mkl-devel
		export LDFLAGS="$LDFLAGS -Wl,-rpath,\$ORIGIN/../../../.."
		;;
esac

if [ -n "${X8664}" ]; then
	LABEL=x8664v4_${LABEL}
	set -- "${@}" "-Cvariant=x86_64::level::${X8664}"
fi

set -- "${@}" "-Cvariant-label=${LABEL}"

if ! grep -q Ubuntu /etc/os-release; then
	sudo xcode-select -s /Applications/Xcode_15.2.app
	ln -s $(which gfortran-13) gfortran
	export PATH=$PWD:$PATH
	export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
	export PKG_CONFIG_PATH=${PWD}
fi

export PKG_CONFIG_PATH
pip install build auditwheel delocate
python -m build -w "${@}"
mkdir wheelhouse

# tag updating needs to be updated for variants
set -- dist/*.whl
old_name=${1#*/}
# strip variant label to avoid issues with auditwheel
mv "${1}" "${1%-*}.whl"

if grep -q Ubuntu /etc/os-release; then
	auditwheel repair --exclude 'libmkl*' dist/*.whl
	mv wheelhouse/*.whl "wheelhouse/${old_name}"
else
	delocate-wheel -w wheelhouse dist/*.whl
	mv wheelhouse/*.whl "wheelhouse/${old_name}"
fi
