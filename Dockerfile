FROM nvidia/cudagl:11.0-devel-ubuntu20.04
# FROM nvidia/cuda:11.1-runtime-ubuntu20.04
# FROM nvidia/cuda:11.1-base-ubuntu20.04

RUN export DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y dialog apt-utils && \
    apt-get upgrade -y && \
    apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    export LANG=en_US.UTF-8 && \
    locale

RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata && \
    ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# install packages
RUN apt-get install -q -y \
    bash-completion \
    cmake \
    dirmngr \
    git \
    gitk \
    gnupg2 \
    libssl-dev \
    lsb-release \
    python3-pip \
    wget

# setup ros2 keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# setup sources.list
RUN echo "deb http://packages.ros.org/ros2-testing/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros2-testing.list

# setup environment
ENV ROS_DISTRO foxy
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV ROSDISTRO_INDEX_URL https://raw.githubusercontent.com/osrf/docker_images/master/ros2/nightly/nightly/index-v4.yaml

# install python packages
RUN pip3 install -U \
    argcomplete \
    flake8 \
    flake8-blind-except \
    flake8-builtins \
    flake8-class-newline \
    flake8-comprehensions \
    flake8-deprecated \
    flake8-docstrings \
    flake8-import-order \
    flake8-quotes \
    pytest-repeat \
    pytest-rerunfailures

# This is a workaround for pytest not found causing builds to fail
# Following RUN statements tests for regression of https://github.com/ros2/ros2/issues/722
RUN pip3 freeze | grep pytest \
    && python3 -m pytest --version

RUN apt-get install -y curl gnupg2 lsb-release && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'  && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y ros-foxy-desktop

# Overwriting _colcon_prefix_chain_sh_COLCON_CURRENT_PREFIX to point to the new install location
# Necessary because the default value is an absolute path valid only on the build machine
RUN sed -i "s|^\(_colcon_prefix_chain_sh_COLCON_CURRENT_PREFIX\s*=\s*\).*$|\1/opt/ros/$ROS_DISTRO|" \
      /opt/ros/$ROS_DISTRO/setup.sh

# install bootstrap tools
RUN apt-get install --no-install-recommends -y \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool 

# setup colcon mixin and metadata
RUN colcon mixin add default \
      https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update && \
    colcon metadata add default \
      https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update

# bootstrap rosdep
RUN rosdep init

# add custom rosdep rule files
COPY prereqs.yaml /etc/ros/rosdep/
RUN echo "yaml file:///etc/ros/rosdep/prereqs.yaml" | \
    cat - /etc/ros/rosdep/sources.list.d/20-default.list > temp && \
    mv temp /etc/ros/rosdep/sources.list.d/20-default.list
RUN rosdep update

# terminator
RUN apt-get update && apt-get autoremove -y \
    && apt-get install -y \
        python3-gi gir1.2-keybinder-3.0 gettext intltool dbus-x11 x11-apps\
        gobject-introspection \
        gir1.2-gtk-3.0 \
        libvte-2.91-dev \
        python-gobject \
        python-gi-cairo \
        libcanberra-gtk-module \
        libcanberra-gtk3-module \
    && /usr/bin/python3 -m pip install psutil configobj && \
    git clone -b v1.92 --single-branch https://github.com/gnome-terminator/terminator.git \
    && cd terminator \
    && python3 setup.py build \
    && python3 setup.py install --record=install-files.txt \
    && cd ..


# setup entrypoint
COPY ./ros_entrypoint.sh /

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]