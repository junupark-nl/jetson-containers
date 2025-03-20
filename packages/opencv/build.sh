#!/usr/bin/env bash
set -ex
echo "Building opencv-python ${OPENCV_VERSION}"

bash /tmp/opencv/install_deps.sh

cd /opt

git clone --branch ${OPENCV_VERSION} --recursive https://github.com/opencv/opencv
git clone --branch ${OPENCV_VERSION} --recursive https://github.com/opencv/opencv_contrib

cd /opt/opencv
git checkout --recurse-submodules "${OPENCV_VERSION}"
cat modules/core/include/opencv2/core/version.hpp

cd /opt/opencv_contrib
git checkout --recurse-submodules "${OPENCV_VERSION}"

cd /opt

# OpenCV looks for the cuDNN version in cudnn_version.h, but it's been renamed to cudnn_version_v8.h
ln -s /usr/include/$(uname -i)-linux-gnu/cudnn_version_v*.h /usr/include/$(uname -i)-linux-gnu/cudnn_version.h

# patches for FP16/half casts
function patch_opencv()
{
    sed -i 's|weight != 1.0|(float)weight != 1.0f|' opencv/modules/dnn/src/cuda4dnn/primitives/normalize_bbox.hpp
    sed -i 's|nms_iou_threshold > 0|(float)nms_iou_threshold > 0.0f|' opencv/modules/dnn/src/cuda4dnn/primitives/region.hpp
    grep 'weight' opencv/modules/dnn/src/cuda4dnn/primitives/normalize_bbox.hpp
    grep 'nms_iou_threshold' opencv/modules/dnn/src/cuda4dnn/primitives/region.hpp
}

patch_opencv
   
export ENABLE_CONTRIB=1
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
export OPENCV_BUILD_ARGS="\
   -DCPACK_BINARY_DEB=ON \
   -DBUILD_EXAMPLES=OFF \
   -DBUILD_opencv_python2=OFF \
   -DBUILD_opencv_python3=OFF \
   -DBUILD_opencv_java=OFF \
   -DCMAKE_BUILD_TYPE=RELEASE \
   -DCMAKE_INSTALL_PREFIX=/usr/local \
   -DCUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
   -DCUDA_ARCH_PTX= \
   -DCUDA_FAST_MATH=ON \
   -DCUDNN_INCLUDE_DIR=/usr/include/$(uname -i)-linux-gnu \
   -DEIGEN_INCLUDE_PATH=/usr/include/eigen3 \
   -DWITH_EIGEN=ON \
   -DENABLE_NEON=ON \
   -DOPENCV_DNN_CUDA=ON \
   -DOPENCV_ENABLE_NONFREE=ON \
   -DOPENCV_GENERATE_PKGCONFIG=ON \
   -DOpenGL_GL_PREFERENCE=GLVND \
   -DWITH_CUBLAS=ON \
   -DWITH_CUDA=ON \
   -DWITH_CUDNN=ON \
   -DWITH_GSTREAMER=ON \
   -DWITH_LIBV4L=ON \
   -DWITH_GTK=ON \
   -DWITH_OPENGL=OFF \
   -DWITH_OPENCL=OFF \
   -DWITH_IPP=OFF \
   -DWITH_TBB=ON \
   -DBUILD_TIFF=ON \
   -DBUILD_PERF_TESTS=OFF \
   -DBUILD_TESTS=OFF"

mkdir /opt/opencv/build
cd /opt/opencv/build

cmake \
    ${OPENCV_BUILD_ARGS} \
    -DOPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
    ../

make -j$(nproc)
make install
make package

mkdir -p /tmp/debs/
cp *.deb /tmp/debs/

tarpack upload OpenCV-${OPENCV_VERSION} /tmp/debs/ || echo "failed to upload tarball"


