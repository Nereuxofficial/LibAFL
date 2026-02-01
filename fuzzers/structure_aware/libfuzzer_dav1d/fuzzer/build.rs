// build.rs

use std::{
    env,
    io::{stdout, Write},
    path::{Path, PathBuf},
    process::exit,
};

use which::which;

fn build_dep_check(tools: &[&str]) {
    for tool in tools {
        println!("Checking for build tool {tool}...");

        if let Ok(path) = which(tool) {
            println!("Found build tool {}", path.to_str().unwrap());
        } else {
            println!("ERROR: missing build tool {tool}");
            exit(1);
        };
    }
}

fn main() {
    if !cfg!(target_os = "linux") {
        println!("cargo:warning=Only linux host is supported for now.");
        exit(0);
    }

    let out_path = PathBuf::from(&env::var_os("OUT_DIR").unwrap());

    println!("cargo:rerun-if-changed=harness.c");

    build_dep_check(&["clang", "clang++"]);

    // Enforce clang for its -fsanitize-coverage support.
    std::env::set_var("CC", "clang");
    std::env::set_var("CXX", "clang++");

    // Find dav1d library
    let dav1d_dir = std::env::current_dir().unwrap().join("..").join("dav1d");
    let dav1d_lib_dir = dav1d_dir.join("build").join("src");
    let dav1d_include_dir = dav1d_dir.join("include");

    if !dav1d_lib_dir.join("libdav1d.a").exists() {
        println!("cargo:warning=dav1d library not found. Run 'just build-dav1d' first.");
        exit(1);
    }

    cc::Build::new()
        // Use sanitizer coverage to track the edges in the PUT
        .flag("-fsanitize-coverage=trace-pc-guard,trace-cmp")
        // Take advantage of LTO (needs lld-link set in your cargo config)
        //.flag("-flto=thin")
        .flag("-Wno-sign-compare")
        .flag("-Wunused-but-set-variable")
        .include(&dav1d_include_dir)
        .file("./harness.c")
        .compile("harness");

    // Link dav1d library
    println!(
        "cargo:rustc-link-search=native={}",
        dav1d_lib_dir.to_string_lossy()
    );
    println!("cargo:rustc-link-lib=static=dav1d");
    println!("cargo:rustc-link-lib=dylib=pthread");
    println!("cargo:rustc-link-lib=dylib=dl");

    println!(
        "cargo:rustc-link-search=native={}",
        &out_path.to_string_lossy()
    );

    let symcc_dir = clone_and_build_symcc(&out_path);

    let runtime_dir = std::env::current_dir().unwrap().join("..").join("runtime");

    // Build the runtime
    std::process::Command::new("cargo")
        .current_dir(&runtime_dir)
        .env_remove("CARGO_TARGET_DIR")
        .arg("build")
        .arg("--release")
        .status()
        .expect("Failed to build runtime");

    std::fs::copy(
        runtime_dir
            .join("target")
            .join("release")
            .join("libSymRuntime.so"),
        runtime_dir.join("libSymRuntime.so"),
    )
    .unwrap();

    if !runtime_dir.join("libSymRuntime.so").exists() {
        println!("cargo:warning=Runtime not found. Build it first.");
        exit(1);
    }

    // SymCC.
    std::env::set_var("CC", symcc_dir.join("symcc"));
    std::env::set_var("CXX", symcc_dir.join("sym++"));
    std::env::set_var("SYMCC_RUNTIME_DIR", runtime_dir);

    println!("cargo:rerun-if-changed=harness_symcc.c");

    // Find dav1d library for symcc build
    let dav1d_dir_symcc = std::env::current_dir().unwrap().join("..").join("dav1d");
    let dav1d_lib_dir_symcc = dav1d_dir_symcc.join("build").join("src");
    let dav1d_include_dir_symcc = dav1d_dir_symcc.join("include");

    let output = cc::Build::new()
        .flag("-Wno-sign-compare")
        .flag("-Wunused-but-set-variable")
        .cargo_metadata(false)
        .get_compiler()
        .to_command()
        .arg(&format!("-I{}", dav1d_include_dir_symcc.to_string_lossy()))
        .arg("./harness_symcc.c")
        .args(["-o", "target_symcc.out"])
        .arg(&format!("-L{}", dav1d_lib_dir_symcc.to_string_lossy()))
        .arg("-ldav1d")
        .arg("-lpthread")
        .arg("-ldl")
        .arg("-lm")
        .arg("-fsanitize-coverage=trace-pc-guard")
        .output()
        .expect("failed to execute symcc");
    if !output.status.success() {
        println!("cargo:warning=Building the target with SymCC failed");
        let mut stdout = stdout();
        stdout
            .write_all(&output.stderr)
            .expect("failed to write cc error message to stdout");
        exit(1);
    }

    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=harness.c");
    println!("cargo:rerun-if-changed=harness_symcc.c");
}

fn clone_and_build_symcc(out_path: &Path) -> PathBuf {
    let repo_dir = out_path.join("libafl_symcc_src");
    if !repo_dir.exists() {
        symcc_libafl::clone_symcc(&repo_dir);
    }

    symcc_libafl::build_symcc(&repo_dir)
}
