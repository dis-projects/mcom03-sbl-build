# MCom-03 Secondary boot loader

Окружение и скрипт для сборки mcom03 sbl.

1. Настройте git

    ```bash
    git config --global user.name 'User'
    git config --global user.email 'user@example.com'
    git config --global color.ui yes
    ```

2. Установите docker по инструкции для используемого дистрибутива

    [CentOS](https://docs.docker.com/engine/install/centos/) /
    [Debian](https://docs.docker.com/engine/install/debian/) /
    [Fedora](https://docs.docker.com/engine/install/fedora/) /
    [RHEL](https://docs.docker.com/engine/install/rhel/) /
    [SLES](https://docs.docker.com/engine/install/sles/) /
    [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

3. Загрузите и распакуйте toolchain для ARM64 и MIPS

    ```bash
    wget https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf.tar.xz
    tar -C /opt/ -xvf gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf.tar.xz
    ```

    ```bash
    wget https://dist.elvees.com/mcom03/buildroot/2022.06/rockpi/images/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz
    tar -C /opt/ -xvzf aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz \
        aarch64-buildroot-linux-gnu_sdk-buildroot/opt/toolchain-mipsel-elvees-elf32/ \
        --strip-components=2
    ```

4. Запустите сборку в контейнере

    ```bash
    ENABLE_NETWORK=1 ./docker-build.sh ./build.sh
    ```
