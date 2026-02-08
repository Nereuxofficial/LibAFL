# Install script for directory: /mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/opt/mozjpeg")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "0")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/llvm-objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib64" TYPE STATIC_LIBRARY FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/libturbojpeg.a")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "tjbench" FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/tjbench-static")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/turbojpeg.h")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib64" TYPE STATIC_LIBRARY FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/libjpeg.a")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "cjpeg" FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/cjpeg-static")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "djpeg" FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/djpeg-static")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "jpegtran" FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jpegtran-static")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/rdjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/llvm-strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/wrjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/llvm-strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/doc" TYPE FILE FILES
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/README.ijg"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/README.md"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/example.txt"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/tjexample.c"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/libjpeg.txt"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/structure.txt"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/usage.txt"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/wizard.txt"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/LICENSE.md"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/man/man1" TYPE FILE FILES
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/cjpeg.1"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/djpeg.1"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jpegtran.1"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/rdjpgcom.1"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/wrjpgcom.1"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib64/pkgconfig" TYPE FILE FILES
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/pkgscripts/libjpeg.pc"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/pkgscripts/libturbojpeg.pc"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jconfig.h"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jerror.h"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jmorecfg.h"
    "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/jpeglib.h"
    )
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/simd/cmake_install.cmake")
  include("/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/md5/cmake_install.cmake")

endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/mnt/SSD/RustroverProjects/LibAFL/fuzzers/inprocess/libfuzzer_libwebp/mozjpeg-4.0.3/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
