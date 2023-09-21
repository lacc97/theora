const std = @import("std");

const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = "1.2.0alpha1+git+zig";

    const ogg_dep = b.dependency("ogg", .{
        .target = target,
        .optimize = optimize,
    });

    const t = target.toTarget();
    const config_header = b.addConfigHeader(.{
        .style = .blank,
        .include_path = "config.h",
    }, .{
        .HAVE_CAIRO = null,
        .HAVE_DLFCN_H = null,
        .HAVE_INTTYPES_H = null,
        .HAVE_MACHINE_SOUNDCARD_H = null,
        .HAVE_MEMORY_CONSTRAINT = null,
        .HAVE_SOUNDCARD_H = null,
        .HAVE_STDINT_H = true,
        .HAVE_STDIO_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = null,
        .HAVE_STRING_H = true,
        .HAVE_SYS_SOUNDCARD_H = null,
        .HAVE_SYS_STAT_H = null,
        .HAVE_SYS_TYPES_H = null,
        .HAVE_UNISTD_H = null,
        .LT_OBJDIR = null,
        .OC_ARM_ASM = null, // TODO: ARM asm is not part of C source
        .OC_ARM_ASM_EDSP = null,
        .OC_ARM_ASM_MEDIA = null,
        .OC_ARM_ASM_NEON = null,
        .OC_C64X_ASM = null,
        .OC_X86_64_ASM = if (t.cpu.arch == .x86_64) true else null,
        .OC_X86_ASM = if (t.cpu.arch.isX86()) true else null,
        .PACKAGE = "libtheora",
        .PACKAGE_BUGREPORT = "none",
        .PACKAGE_NAME = "libtheora",
        .PACKAGE_STRING = "libtheora " ++ version,
        .PACKAGE_TARNAME = "libtheora",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = version,
        .STDC_HEADERS = true,
        .THEORA_DISABLE_ENCODE = null,
        .VERSION = version,
    });

    const enclib = b.addStaticLibrary(.{
        .name = "theoraenc",
        .target = target,
        .optimize = optimize,
    });

    enclib.defineCMacro("DHAVE_CONFIG_H", null);
    enclib.addConfigHeader(config_header);
    enclib.addIncludePath(.{ .path = "include" });
    enclib.addCSourceFiles(&encoder_base_sources, &base_flags);
    if (t.cpu.arch.isX86()) enclib.addCSourceFiles(&encoder_x86_sources, &base_flags);
    if (t.cpu.arch == .x86_64) enclib.addCSourceFiles(&encoder_x86_64_sources, &base_flags);
    enclib.linkLibrary(ogg_dep.artifact("ogg"));

    const declib = b.addStaticLibrary(.{
        .name = "theoradec",
        .target = target,
        .optimize = optimize,
    });

    declib.defineCMacro("DHAVE_CONFIG_H", null);
    declib.addConfigHeader(config_header);
    declib.addIncludePath(.{ .path = "include" });
    declib.addCSourceFiles(&decoder_base_sources, &base_flags);
    if (t.cpu.arch.isX86()) declib.addCSourceFiles(&decoder_x86_sources, &base_flags);
    declib.linkLibrary(ogg_dep.artifact("ogg"));

    const lib = b.addStaticLibrary(.{
        .name = "theora",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibrary(enclib);
    lib.linkLibrary(declib);
    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{ .path = "include/theora" },
        .install_dir = .header,
        .install_subdir = "theora",
        .exclude_extensions = &.{".am"},
    });
    b.installArtifact(lib);

    buildExamples(b, lib);
}

fn buildExamples(b: *Build, lib: *Build.Step.Compile) void {
    const examples_step = b.step("examples", "Build and install examples");

    const libtheora_info = b.addExecutable(.{
        .name = "libtheora_info",
        .target = lib.target,
        .optimize = lib.optimize,
    });
    libtheora_info.addCSourceFiles(&.{"examples/libtheora_info.c"}, &.{});
    libtheora_info.linkLibrary(lib);
    examples_step.dependOn(&b.addInstallArtifact(libtheora_info, .{}).step);
}

const base_flags = [_][]const u8{
    "-fno-sanitize=undefined",
    "-Wno-parentheses",
};

const encoder_base_sources = [_][]const u8{
    "lib/apiwrapper.c",
    "lib/bitpack.c",
    "lib/dequant.c",
    "lib/fragment.c",
    "lib/idct.c",
    "lib/internal.c",
    "lib/state.c",
    "lib/quant.c",
    "lib/analyze.c",
    "lib/fdct.c",
    "lib/encfrag.c",
    "lib/encapiwrapper.c",
    "lib/encinfo.c",
    "lib/encode.c",
    "lib/enquant.c",
    "lib/huffenc.c",
    "lib/mathops.c",
    "lib/mcenc.c",
    "lib/rate.c",
    "lib/tokenize.c",
};
const encoder_x86_sources = [_][]const u8{
    "lib/x86/x86cpu.c",
    "lib/x86/mmxfrag.c",
    "lib/x86/mmxidct.c",
    "lib/x86/mmxstate.c",
    "lib/x86/sse2idct.c",
    "lib/x86/x86state.c",

    "lib/x86/mmxencfrag.c",
    "lib/x86/mmxfdct.c",
    "lib/x86/sse2encfrag.c",
    "lib/x86/x86enquant.c",
    "lib/x86/x86enc.c",
};
const encoder_x86_64_sources = [_][]const u8{
    "lib/x86/sse2fdct.c",
};

const decoder_base_sources = [_][]const u8{
    "lib/apiwrapper.c",
    "lib/bitpack.c",
    "lib/decapiwrapper.c",
    "lib/decinfo.c",
    "lib/decode.c",
    "lib/dequant.c",
    "lib/fragment.c",
    "lib/huffdec.c",
    "lib/idct.c",
    "lib/info.c",
    "lib/internal.c",
    "lib/quant.c",
    "lib/state.c",
};
const decoder_x86_sources = [_][]const u8{
    "lib/x86/x86cpu.c",
    "lib/x86/mmxidct.c",
    "lib/x86/mmxfrag.c",
    "lib/x86/mmxstate.c",
    "lib/x86/sse2idct.c",
    "lib/x86/x86state.c",
};

fn have_x86_feat(t: std.Target, feat: std.Target.x86.Feature) c_int {
    return @intFromBool(switch (t.cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(t.cpu.features, feat),
        else => false,
    });
}

fn have_arm_feat(t: std.Target, feat: std.Target.arm.Feature) c_int {
    return @intFromBool(switch (t.cpu.arch) {
        .arm, .armeb => std.Target.arm.featureSetHas(t.cpu.features, feat),
        else => false,
    });
}
