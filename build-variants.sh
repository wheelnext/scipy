#!/bin/sh

set -ex

pip config set global.extra-index-url https://pypi.anaconda.org/mgorny/simple

LABEL=${BLAS:-openblas}
case ${BLAS:-openblas} in
	openblas)
		export PKG_CONFIG_PATH=${PWD}
		;;
	mkl)
		pip install mkl-devel
		export LDFLAGS="$LDFLAGS -Wl,-rpath,\$ORIGIN/../../../.."
		;;
esac

if [ -n "${X8664}" ]; then
	LABEL=x8664v4_${LABEL}
fi

set -- "${@}" "-Cvariant-label=${LABEL}"

if ! grep -q Ubuntu /etc/os-release; then
	sudo xcode-select -s /Applications/Xcode_15.2.app
	ln -s $(which gfortran-13) gfortran
	export PATH=$PWD:$PATH
	export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
	export PKG_CONFIG_PATH=${PWD}
fi

. tools/wheels/cibw_before_build.sh "${PWD}"
export PKG_CONFIG_PATH=${pkgconf_path}:$(python -c "import sys; print(sys.prefix)")/lib/pkgconfig
pip install build auditwheel delocate patchelf
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
